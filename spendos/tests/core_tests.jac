"""SpendOS deterministic and graph workflow tests."""

import from schema {
    BudgetPlan,
    CaseFor,
    Contains,
    Decision,
    PricePoint,
    PurchaseProposal,
    SimulatedAction,
    ShoppingCandidate,
    ShoppingCandidateInput,
    ShoppingMission,
    Statement,
    Subscription,
    SubscriptionCase,
    Transaction,
    calculate_safe_to_spend,
    detect_recurrence,
    normalize_merchant,
    normalize_purchase_monthly_cost,
    parse_statement_csv,
}
import from endpoints {
    AnalyzePortfolio,
    DecideCase,
    ImportStatement,
    SimulateCancellation,
    decide_purchase_proposal,
    claim_shopping_mission,
    complete_shopping_mission,
    create_shopping_mission,
    get_dashboard,
    propose_purchase,
    save_budget_plan,
    simulate_purchase,
    submit_shopping_candidate,
}


glob FIXTURE: str = """date,description,amount
2025-01-05,Netflix.com,-20.00
2025-02-05,NETFLIX.COM 9921,-20.00
2025-03-05,Netflix recurring,-22.00
2025-01-12,Disney Plus,-15.00
2025-02-12,DISNEY PLUS,-15.00
2025-03-12,Disney Plus recurring,-15.00
bad-date,Broken row,-9.00""";


def clear_graph {
    for item in [root-->] {
        del item;
    }
}


test "merchant normalization removes processor noise" {
    assert normalize_merchant("POS Netflix.com 9921") == "NETFLIX";
    assert normalize_merchant("Netflix recurring") == "NETFLIX";
}


test "csv preview reports totals and malformed rows" {
    preview = parse_statement_csv(FIXTURE);
    assert len(preview.transactions) == 6;
    assert len(preview.rejected) == 1;
    assert preview.rejected[0].row_number == 8;
    assert preview.debit_total == 107.0;
}

test "detailed bank columns survive parsing" {
    detailed = """date,description,amount,merchant,category,subcategory,account_name,account_mask,transaction_type,payment_channel,city,region,country,pending
2026-07-21,OPENAI CHATGPT PLUS,-20.00,OpenAI,Software,AI Tools,Rewards Card,1944,DEBIT,online,San Francisco,CA,US,true""";
    preview = parse_statement_csv(detailed);
    assert len(preview.transactions) == 1;
    transaction = preview.transactions[0];
    assert transaction.merchant_name == "OPENAI";
    assert transaction.category == "Software";
    assert transaction.subcategory == "AI Tools";
    assert transaction.account_mask == "1944";
    assert transaction.payment_channel == "online";
    assert transaction.city == "San Francisco";
    assert transaction.pending;
}


test "recurrence detector finds monthly charges and price change" {
    detected = detect_recurrence(
        [
            PricePoint(date="2025-01-05", amount=-20.0),
            PricePoint(date="2025-02-05", amount=-20.0),
            PricePoint(date="2025-03-05", amount=-22.0),

        ]
    );
    assert detected is not None;
    assert detected.cadence == "MONTHLY";
    assert detected.transaction_count == 3;
    assert detected.price_change == 2.0;
    assert detected.confidence >= 0.8;
}

test "safe to spend reserves every obligation deterministically" {
    assert calculate_safe_to_spend(5000.0, 2500.0, 100.0, 500.0) == 1900.0;
    assert calculate_safe_to_spend(1000.0, 800.0, 250.0, 100.0) == -150.0;
}

test "purchase cadence normalization is deterministic" {
    assert normalize_purchase_monthly_cost(24.0, "MONTHLY") == 24.0;
    assert normalize_purchase_monthly_cost(90.0, "QUARTERLY") == 30.0;
    assert normalize_purchase_monthly_cost(120.0, "ANNUAL") == 10.0;
}


test "statement import and analysis are idempotent" {
    clear_graph();
    first = root spawn ImportStatement(csv_text=FIXTURE, currency="USD");
    assert first.reports[0].imported_count == 6;
    root spawn AnalyzePortfolio();
    assert len([root-->[?:Statement]]) == 1;
    assert len([root-->[?:Statement]->:Contains:->[?:Transaction]]) == 6;
    assert len([root-->[?:Subscription]]) == 2;

    second = root spawn ImportStatement(csv_text=FIXTURE, currency="USD");
    root spawn AnalyzePortfolio();
    assert second.reports[0].imported_count == 0;
    assert second.reports[0].duplicate_count == 6;
    assert len([root-->[?:Statement]]) == 1;
    assert len([root-->[?:Statement]->:Contains:->[?:Transaction]]) == 6;
    assert len([root-->[?:Subscription]]) == 2;
}


test "approved cancellation is simulated exactly once" {
    clear_graph();
    target = root ++> Subscription(
        subscription_id="subscription_test",
        merchant_id="merchant_test",
        merchant_name="Test Streaming",
        cadence="MONTHLY",
        monthly_cost=20.0,
        last_amount=20.0,
        next_expected="2025-04-05",
        confidence=0.9,
        transaction_count=3
    );
    target_case = root ++> SubscriptionCase(
        case_id="case_test_cancel",
        subscription_id=target.subscription_id,
        merchant_name=target.merchant_name,
        recommendation="CANCEL",
        reason="Test overlap case.",
        annual_savings=240.0,
        confidence=0.9,
        evidence_ids=["evidence_test"],
        source="deterministic",
        created_at="2025-03-20T00:00:00Z"
    );
    target_case +>:CaseFor:+> target;
    first = root spawn DecideCase(case_id="case_test_cancel", choice="APPROVE_CANCEL");
    second = root spawn DecideCase(case_id="case_test_cancel", choice="APPROVE_CANCEL");
    assert first.reports[0] == second.reports[0];
    assert len([root-->[?:Decision, case_id=="case_test_cancel"]]) == 1;
    actions: list[SimulatedAction] = [root-->[?:SimulatedAction, case_id=="case_test_cancel"]];
    assert len(actions) == 1;
    assert actions[0].state == "APPROVED";

    root spawn SimulateCancellation(action_id=actions[0].action_id);
    root spawn SimulateCancellation(action_id=actions[0].action_id);
    assert actions[0].state == "SIMULATED";
    assert actions[0].simulated_at != "";
}


test "budget plan updates one graph node and includes subscriptions" {
    clear_graph();
    root ++> Subscription(
        subscription_id="subscription_budget",
        merchant_id="merchant_budget",
        merchant_name="Budget Stream",
        cadence="MONTHLY",
        monthly_cost=25.0,
        last_amount=25.0,
        next_expected="2025-04-05",
        confidence=0.95,
        transaction_count=3
    );
    first = save_budget_plan(3000.0, 1500.0, 300.0);
    second = save_budget_plan(3200.0, 1600.0, 400.0);
    unsafe = save_budget_plan(1000.0, 800.0, 300.0);
    assert first.safe_to_spend == 1175.0;
    assert second.safe_to_spend == 1175.0;
    assert second.status == "SAFE";
    assert unsafe.safe_to_spend == -125.0;
    assert unsafe.status == "UNSAFE";
    assert "exceeds monthly income" in unsafe.warning;
    assert len([root-->[?:BudgetPlan]]) == 1;
    assert [root-->[?:BudgetPlan]][0].monthly_income == 1000.0;
}


test "purchase preflight returns safe warning block and review" {
    clear_graph();
    review = propose_purchase("hermes", "No Budget App", "Research", 12.0, "MONTHLY");
    assert review.outcome == "REVIEW";
    assert review.state == "AWAITING_APPROVAL";

    clear_graph();
    save_budget_plan(2000.0, 1000.0, 400.0);
    safe = propose_purchase("hermes", "Safe App", "Coding", 50.0, "MONTHLY");
    assert safe.outcome == "SAFE";
    assert safe.projected_safe_to_spend == 550.0;

    save_budget_plan(2000.0, 1450.0, 400.0);
    warning = propose_purchase("hermes", "Warn App", "Coding", 75.0, "MONTHLY");
    assert warning.outcome == "WARN";
    assert warning.projected_safe_to_spend == 75.0;

    blocked = propose_purchase("hermes", "Blocked App", "Coding", 200.0, "MONTHLY");
    assert blocked.outcome == "BLOCK";
    assert blocked.state == "BLOCKED";
}


test "purchase proposals and simulation are idempotent" {
    clear_graph();
    save_budget_plan(3000.0, 1000.0, 500.0);
    first = propose_purchase("hermes", "Code Tool", "Development", 120.0, "ANNUAL");
    second = propose_purchase("hermes", "Code Tool", "Development", 120.0, "ANNUAL");
    assert first.proposal_id == second.proposal_id;
    assert len([root-->[?:PurchaseProposal]]) == 1;

    approved = decide_purchase_proposal(first.proposal_id, "APPROVE");
    assert approved.state == "APPROVED";
    simulated = simulate_purchase(first.proposal_id);
    repeated = simulate_purchase(first.proposal_id);
    assert simulated.state == "SIMULATED";
    assert repeated.state == "SIMULATED";
    assert repeated.decided_at != "";
}


test "purchase proposals reevaluate without duplicating nodes" {
    clear_graph();
    review = propose_purchase(
        "hermes", "Adaptive Tool", "Development", 120.0, "ANNUAL"
    );
    refused = decide_purchase_proposal(review.proposal_id, "APPROVE");
    assert refused.outcome == "REVIEW";
    assert refused.state == "AWAITING_APPROVAL";
    assert refused.decided_at == "";

    save_budget_plan(2000.0, 1000.0, 400.0);
    reevaluated = propose_purchase(
        "hermes", "Adaptive Tool", "Development", 120.0, "ANNUAL"
    );
    assert reevaluated.proposal_id == review.proposal_id;
    assert reevaluated.outcome == "SAFE";
    assert reevaluated.state == "PROPOSED";
    assert reevaluated.projected_safe_to_spend == 590.0;
    assert len([root-->[?:PurchaseProposal]]) == 1;
}

test "shopping mission completes a two way agent loop safely" {
    clear_graph();
    created = create_shopping_mission(
        "Find a quiet mechanical keyboard", 150.0, "Mac compatible; no subscription"
    );
    repeated = create_shopping_mission(
        "Find a quiet mechanical keyboard", 150.0, "Mac compatible; no subscription"
    );
    assert created.mission_id == repeated.mission_id;
    assert created.status == "DISPATCHED";
    assert len([root-->[?:ShoppingMission]]) == 1;

    claimed = claim_shopping_mission(created.mission_id, "hermes");
    assert claimed.status == "IN_PROGRESS";
    assert claimed.assigned_agent == "hermes";

    safe_candidate = submit_shopping_candidate(
        created.mission_id,
        "hermes",
        ShoppingCandidateInput(
            merchant="Keyboard Store",
            product="Quiet Keys",
            price=120.0,
            shipping=5.0,
            evidence="Merchant listing checked by Hermes."
        )
    );
    assert safe_candidate.within_budget;

    recurring_candidate = submit_shopping_candidate(
        created.mission_id,
        "hermes",
        ShoppingCandidateInput(
            merchant="Keyboard Club",
            product="Member Keys",
            price=90.0,
            recurring_cost=10.0,
            evidence="Listing requires a monthly membership."
        )
    );
    assert not recurring_candidate.within_budget;
    assert "recurring cost" in recurring_candidate.warning;

    completed = complete_shopping_mission(created.mission_id, "hermes");
    repeated_completion = complete_shopping_mission(created.mission_id, "hermes");
    assert completed.status == "READY_FOR_REVIEW";
    assert repeated_completion.status == "READY_FOR_REVIEW";
    assert len(completed.candidates) == 2;
    assert len([root-->[?:ShoppingCandidate]]) == 2;
}

test "dashboard spending analytics are deterministic and dashboard ready" {
    clear_graph();
    statement = root ++> Statement(
        statement_id="statement_analytics",
        fingerprint="analytics",
        currency="USD",
        imported_at="2026-07-26T00:00:00Z"
    );
    rows: list[Transaction] = [
        Transaction(
            transaction_id="income",
            fingerprint="income",
            date="2026-07-01",
            description="Payroll",
            amount=5000.0,
            currency="USD",
            category="Income"
        ),
        Transaction(
            transaction_id="amazon_one",
            fingerprint="amazon_one",
            date="2026-07-20",
            description="Amazon Purchase",
            amount=-100.0,
            currency="USD",
            category="Shopping"
        ),
        Transaction(
            transaction_id="amazon_two",
            fingerprint="amazon_two",
            date="2026-07-21",
            description="Amazon Purchase",
            amount=-50.0,
            currency="USD",
            category="Shopping"
        ),
        Transaction(
            transaction_id="mystery",
            fingerprint="mystery",
            date="2026-07-22",
            description="Mystery Merchant",
            amount=-300.0,
            currency="USD"
        ),
        Transaction(
            transaction_id="old",
            fingerprint="old",
            date="2026-06-22",
            description="Old Purchase",
            amount=-999.0,
            currency="USD",
            category="Shopping"
        )
    ];
    for row in rows {
        statement +>:Contains:+> row;
    }
    root ++> Subscription(
        subscription_id="analytics_subscription",
        merchant_id="analytics_merchant",
        merchant_name="Streaming",
        cadence="MONTHLY",
        monthly_cost=12.0,
        last_amount=12.0,
        next_expected="2026-08-02",
        confidence=0.95,
        transaction_count=3
    );
    dashboard = get_dashboard();
    spending = dashboard.spending;
    assert spending.period == "2026-07";
    assert spending.income == 5000.0;
    assert spending.total_spend == 450.0;
    assert spending.net_income == 4550.0;
    assert len(spending.category_breakdown) == 2;
    assert spending.category_breakdown[0].category == "Uncategorized";
    assert spending.category_breakdown[0].amount == 300.0;
    assert spending.category_breakdown[1].percentage == 33.3;
    assert len(spending.frequent_merchants) == 1;
    assert spending.frequent_merchants[0].merchant == "Amazon";
    assert spending.frequent_merchants[0].transaction_count == 2;
    assert spending.frequent_merchants[0].average_amount == 75.0;
    assert spending.largest_purchases[0].transaction_id == "mystery";
    assert len(spending.uncategorized) == 1;
    assert len(spending.upcoming_recurring) == 1;
}
