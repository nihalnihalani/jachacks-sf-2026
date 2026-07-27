"""SpendOS server endpoints and graph workflows."""

import os;
import from schema {
    ActionView,
    AgentIdentity,
    ActsOn,
    AppliesTo,
    BudgetPlan,
    BudgetView,
    CaseFor,
    CaseView,
    CandidateFor,
    CategorySpendView,
    Contains,
    Dashboard,
    Decision,
    DecidedBy,
    Establishes,
    Evidence,
    ImportPreview,
    ImportResult,
    Merchant,
    PaidTo,
    ParsedTransaction,
    Precedent,
    Preference,
    PricePoint,
    ProposedBy,
    PurchaseProposal,
    PurchaseProposalView,
    RecursAs,
    SimulatedAction,
    ShoppingCandidate,
    ShoppingCandidateInput,
    ShoppingCandidateView,
    ShoppingMission,
    ShoppingMissionView,
    SpendingAnalytics,
    Statement,
    Subscription,
    SubscriptionCase,
    SubscriptionView,
    SupportedBy,
    Transaction,
    TransactionView,
    MerchantSpendView,
    calculate_safe_to_spend,
    detect_recurrence,
    normalize_merchant,
    normalize_purchase_monthly_cost,
    now_iso,
    parse_statement_csv,
    stable_id,
}
import from agent {
    InvestigationPacket,
    assess_subscription,
    citations_are_valid,
    live_agent_available,
}
import from purchase {
    AuditEntry,
    Cart,
    CartLine,
    CartLineView,
    CartView,
    CatalogProductView,
    Holds,
    Included,
    OrderLine,
    ParsedPurchaseInstruction,
    PurchaseOrder,
    PurchaseResultView,
    ResolvedPurchaseLine,
    SimulatedOrderView,
    compute_cart_totals,
    parse_purchase_instruction,
    search_catalog,
}

def transaction_to_view(transaction: Transaction) -> TransactionView {
    location_parts: list[str] = [
        part
        for part in [transaction.city, transaction.region, transaction.country]
        if part
    ];
    return TransactionView(
        transaction_id=transaction.transaction_id,
        date=transaction.date,
        description=transaction.description,
        merchant=normalize_merchant(transaction.description).title(),
        amount=transaction.amount,
        currency=transaction.currency,
        category=transaction.category,
        subcategory=transaction.subcategory,
        account_name=transaction.account_name,
        account_mask=transaction.account_mask,
        transaction_type=transaction.transaction_type,
        payment_channel=transaction.payment_channel,
        location=", ".join(location_parts),
        pending=transaction.pending
    );
}


def subscription_to_view(sub: Subscription) -> SubscriptionView {
    return SubscriptionView(
        subscription_id=sub.subscription_id,
        merchant=sub.merchant_name,
        cadence=sub.cadence,
        monthly_cost=sub.monthly_cost,
        last_amount=sub.last_amount,
        next_expected=sub.next_expected,
        confidence=sub.confidence,
        price_change=sub.price_change,
        status=sub.status,
        protected=sub.protected,
        transaction_count=sub.transaction_count
    );
}


def case_to_view(case_item: SubscriptionCase) -> CaseView {
    return CaseView(
        case_id=case_item.case_id,
        subscription_id=case_item.subscription_id,
        merchant=case_item.merchant_name,
        recommendation=case_item.recommendation,
        reason=case_item.reason,
        annual_savings=case_item.annual_savings,
        confidence=case_item.confidence,
        evidence_ids=case_item.evidence_ids,
        source=case_item.source,
        state=case_item.state
    );
}


def action_to_view(action: SimulatedAction) -> ActionView {
    return ActionView(
        action_id=action.action_id,
        case_id=action.case_id,
        merchant=action.merchant_name,
        state=action.state,
        annual_savings=action.annual_savings,
        approved_at=action.approved_at,
        simulated_at=action.simulated_at
    );
}

def proposal_to_view(proposal: PurchaseProposal) -> PurchaseProposalView {
    return PurchaseProposalView(
        proposal_id=proposal.proposal_id,
        agent_id=proposal.agent_id,
        merchant=proposal.merchant,
        purpose=proposal.purpose,
        amount=proposal.amount,
        cadence=proposal.cadence,
        monthly_cost=proposal.monthly_cost,
        projected_safe_to_spend=proposal.projected_safe_to_spend,
        outcome=proposal.outcome,
        state=proposal.state,
        reason=proposal.reason,
        created_at=proposal.created_at,
        decided_at=proposal.decided_at
    );
}

def candidate_to_view(
    candidate: ShoppingCandidate, maximum_budget: float
) -> ShoppingCandidateView {
    total: float = round(candidate.price + candidate.shipping, 2);
    within_budget = total <= maximum_budget and candidate.recurring_cost <= 0.0;
    warning = "";
    if candidate.recurring_cost > 0.0 {
        warning = f"Includes an unapproved recurring cost of {candidate.recurring_cost:.2f} per month.";
    } elif total > maximum_budget {
        warning = f"Total cost exceeds the mission budget by {total - maximum_budget:.2f}.";
    }
    return ShoppingCandidateView(
        candidate_id=candidate.candidate_id,
        mission_id=candidate.mission_id,
        merchant=candidate.merchant,
        product=candidate.product,
        price=candidate.price,
        shipping=candidate.shipping,
        recurring_cost=candidate.recurring_cost,
        product_url=candidate.product_url,
        evidence=candidate.evidence,
        within_budget=within_budget,
        warning=warning
    );
}

def mission_to_view(mission: ShoppingMission) -> ShoppingMissionView {
    candidate_views: list[ShoppingCandidateView] = [];
    target_mission_id = mission.mission_id;
    candidates: list[ShoppingCandidate] = [root-->[?:ShoppingCandidate, mission_id==target_mission_id]];
    for candidate in candidates {
        candidate_views.append(candidate_to_view(candidate, mission.maximum_budget));
    }
    candidate_views = sorted(
        candidate_views,
        key=lambda (item: ShoppingCandidateView) { item.price + item.shipping; }
    );
    return ShoppingMissionView(
        mission_id=mission.mission_id,
        request=mission.request,
        maximum_budget=mission.maximum_budget,
        preferences=mission.preferences,
        status=mission.status,
        assigned_agent=mission.assigned_agent,
        created_at=mission.created_at,
        updated_at=mission.updated_at,
        candidates=candidate_views
    );
}

def build_spending_analytics(
    transactions: list[Transaction], subscriptions: list[Subscription]
) -> SpendingAnalytics {
    if not transactions {
        return SpendingAnalytics();
    }
    latest_date = max([transaction.date for transaction in transactions]);
    period = latest_date[0:7];
    period_transactions: list[Transaction] = [
        transaction
        for transaction in transactions
        if transaction.date[0:7] == period
    ];
    income: float = 0.0;
    total_spend: float = 0.0;
    category_totals: dict[str, float] = {};
    category_counts: dict[str, int] = {};
    merchant_totals: dict[str, float] = {};
    merchant_counts: dict[str, int] = {};
    purchases: list[TransactionView] = [];
    uncategorized: list[TransactionView] = [];
    for transaction in period_transactions {
        if transaction.amount > 0.0 {
            income += transaction.amount;
            continue;
        }
        if transaction.amount == 0.0 {
            continue;
        }
        spend_amount: float = abs(transaction.amount);
        total_spend += spend_amount;
        category = transaction.category.strip() or "Uncategorized";
        current_category_total: float = category_totals[category]
            if category in category_totals
            else 0.0;
        category_totals[category] = current_category_total + spend_amount;
        current_category_count: int = category_counts[category]
            if category in category_counts
            else 0;
        category_counts[category] = current_category_count + 1;
        merchant = normalize_merchant(transaction.description).title();
        current_merchant_total: float = merchant_totals[merchant]
            if merchant in merchant_totals
            else 0.0;
        merchant_totals[merchant] = current_merchant_total + spend_amount;
        current_merchant_count: int = merchant_counts[merchant]
            if merchant in merchant_counts
            else 0;
        merchant_counts[merchant] = current_merchant_count + 1;
        transaction_view = transaction_to_view(transaction);
        purchases.append(transaction_view);
        if category.upper() == "UNCATEGORIZED" {
            uncategorized.append(transaction_view);
        }
    }
    category_breakdown: list[CategorySpendView] = [];
    for category in category_totals {
        amount = category_totals[category];
        percentage = round((amount / total_spend) * 100.0, 1) if total_spend else 0.0;
        category_breakdown.append(
            CategorySpendView(
                category=category,
                amount=round(amount, 2),
                percentage=percentage,
                transaction_count=category_counts[category]
            )
        );
    }
    category_breakdown = sorted(
        category_breakdown, key=lambda (item: CategorySpendView) { 0.0 - item.amount; }
    );
    frequent_merchants: list[MerchantSpendView] = [];
    for merchant in merchant_totals {
        amount = merchant_totals[merchant];
        count = merchant_counts[merchant];
        if count >= 2 {
            frequent_merchants.append(
                MerchantSpendView(
                    merchant=merchant,
                    transaction_count=count,
                    average_amount=round(amount / count, 2),
                    total_amount=round(amount, 2)
                )
            );
        }
    }
    frequent_merchants = sorted(
        frequent_merchants,
        key=lambda (item: MerchantSpendView) { 0 - item.transaction_count; }
    );
    purchases = sorted(purchases, key=lambda (item: TransactionView) { item.amount; })[0:5];
    uncategorized = sorted(
        uncategorized, key=lambda (item: TransactionView) { item.amount; }
    )[0:8];
    upcoming_recurring: list[SubscriptionView] = [
        subscription_to_view(subscription)
        for subscription in subscriptions
        if subscription.status == "ACTIVE" or subscription.status == "PROTECTED"
    ];
    upcoming_recurring = sorted(
        upcoming_recurring, key=lambda (item: SubscriptionView) { item.next_expected; }
    );
    return SpendingAnalytics(
        period=period,
        income=round(income, 2),
        total_spend=round(total_spend, 2),
        net_income=round(income - total_spend, 2),
        category_breakdown=category_breakdown,
        frequent_merchants=frequent_merchants,
        largest_purchases=purchases,
        uncategorized=uncategorized,
        upcoming_recurring=upcoming_recurring
    );
}


def:pub preview_statement(csv_text: str, currency: str = "USD") -> ImportPreview {
    return parse_statement_csv(csv_text, currency);
}

def:pub get_synthetic_feed -> str {
    source_path: str = os.path.join(
        os.path.dirname(__file__), "data", "synthetic_bank_feed.csv"
    );
    with open(source_path) as source {
        return source.read();
    }
}


def:pub get_dashboard(cache_bust: int = 0) -> Dashboard {
    _ = cache_bust;
    statements: list[Statement] = [root-->[?:Statement]];
    transactions: list[Transaction] = [root-->[?:Statement]->:Contains:->[?:Transaction]];
    subscriptions: list[Subscription] = [root-->[?:Subscription]];
    cases: list[SubscriptionCase] = [root-->[?:SubscriptionCase]];
    actions: list[SimulatedAction] = [root-->[?:SimulatedAction]];
    proposals: list[PurchaseProposal] = [root-->[?:PurchaseProposal]];
    shopping_missions: list[ShoppingMission] = [root-->[?:ShoppingMission]];
    budgets: list[BudgetPlan] = [root-->[?:BudgetPlan]];
    subscription_views: list[SubscriptionView] = [];
    case_views: list[CaseView] = [];
    action_views: list[ActionView] = [];
    proposal_views: list[PurchaseProposalView] = [];
    mission_views: list[ShoppingMissionView] = [];
    transaction_views: list[TransactionView] = [];
    monthly_total: float = 0.0;
    for sub in subscriptions {
        subscription_views.append(subscription_to_view(sub));
        if sub.status == "ACTIVE" {
            monthly_total += sub.monthly_cost;
        }
    }
    for case_item in cases {
        case_views.append(case_to_view(case_item));
    }
    for action in actions {
        action_views.append(action_to_view(action));
    }
    for proposal in proposals {
        proposal_views.append(proposal_to_view(proposal));
    }
    for mission in shopping_missions {
        mission_views.append(mission_to_view(mission));
    }
    for transaction in transactions {
        transaction_views.append(transaction_to_view(transaction));
    }
    transaction_views = sorted(
        transaction_views,
        key=lambda (item: TransactionView) { item.date + "|" + item.transaction_id; },
        reverse=True
    )[0:12];
    subscription_views = sorted(
        subscription_views,
        key=lambda (item: SubscriptionView) { 0.0 - item.monthly_cost; }
    );
    case_views = sorted(case_views, key=lambda (item: CaseView) { item.case_id; });
    budget_view = BudgetView(recurring_obligations=round(monthly_total, 2));
    if budgets {
        plan = budgets[0];
        safe_amount = calculate_safe_to_spend(
            plan.monthly_income,
            plan.fixed_obligations,
            monthly_total,
            plan.safety_reserve
        );
        budget_status = "SAFE";
        budget_warning = "";
        if safe_amount < 0.0 {
            budget_status = "UNSAFE";
            budget_currency = statements[0].currency if statements else "USD";
            budget_warning = f"The confirmed plan exceeds monthly income by {0.0 - safe_amount:.2f} {budget_currency}. Reduce obligations or the reserve before adding new spending.";
        }
        budget_view = BudgetView(
            configured=True,
            monthly_income=plan.monthly_income,
            fixed_obligations=plan.fixed_obligations,
            recurring_obligations=round(monthly_total, 2),
            safety_reserve=plan.safety_reserve,
            safe_to_spend=safe_amount,
            status=budget_status,
            warning=budget_warning,
            confirmed_at=plan.confirmed_at
        );
    }
    return Dashboard(
        has_data=len(statements) > 0,
        statement_count=len(statements),
        transaction_count=len(transactions),
        subscription_count=len(subscriptions),
        monthly_total=round(monthly_total, 2),
        annual_total=round(monthly_total * 12.0, 2),
        currency=statements[0].currency if statements else "USD",
        recent_transactions=transaction_views,
        subscriptions=subscription_views,
        cases=case_views,
        actions=action_views,
        proposals=proposal_views,
        shopping_missions=mission_views,
        spending=build_spending_analytics(transactions, subscriptions),
        budget=budget_view
    );
}

def:pub create_shopping_mission(
    shopping_request: str, maximum_budget: float, preferences: str = ""
) -> ShoppingMissionView {
    normalized_request = shopping_request.strip();
    normalized_preferences = preferences.strip();
    if not normalized_request {
        raise ValueError("A shopping request is required.");
    }
    if maximum_budget <= 0.0 {
        raise ValueError("Maximum budget must be greater than zero.");
    }
    target_mission_id = stable_id(
        "mission",
        f"{normalized_request.upper()}|{round(maximum_budget, 2):.2f}|{normalized_preferences.upper()}"
    );
    existing: list[ShoppingMission] = [root-->[?:ShoppingMission, mission_id==target_mission_id]];
    if existing {
        return mission_to_view(existing[0]);
    }
    created = now_iso();
    mission = root ++> ShoppingMission(
        mission_id=target_mission_id,
        request=normalized_request,
        maximum_budget=round(maximum_budget, 2),
        preferences=normalized_preferences,
        status="DISPATCHED",
        created_at=created,
        updated_at=created
    );
    return mission_to_view(mission);
}

def:pub claim_shopping_mission(mission_id: str, agent_id: str) -> ShoppingMissionView {
    target_mission_id = mission_id.strip();
    missions: list[ShoppingMission] = [root-->[?:ShoppingMission, mission_id==target_mission_id]];
    if not missions {
        raise ValueError("Shopping mission was not found.");
    }
    mission = missions[0];
    normalized_agent = agent_id.strip();
    if not normalized_agent {
        raise ValueError("Agent identity is required.");
    }
    if mission.status == "DISPATCHED" {
        mission.status = "IN_PROGRESS";
        mission.assigned_agent = normalized_agent;
        mission.updated_at = now_iso();
    } elif mission.assigned_agent != normalized_agent {
        raise ValueError("Shopping mission is already assigned to another agent.");
    }
    return mission_to_view(mission);
}

def:pub submit_shopping_candidate(
    mission_id: str, agent_id: str, candidate_input: ShoppingCandidateInput
) -> ShoppingCandidateView {
    target_mission_id = mission_id.strip();
    missions: list[ShoppingMission] = [root-->[?:ShoppingMission, mission_id==target_mission_id]];
    if not missions {
        raise ValueError("Shopping mission was not found.");
    }
    mission = missions[0];
    if mission.status != "IN_PROGRESS" or mission.assigned_agent != agent_id.strip() {
        raise ValueError(
            "The assigned agent must claim this mission before returning results."
        );
    }
    if (
        not candidate_input.merchant.strip()
        or not candidate_input.product.strip()
        or not candidate_input.evidence.strip()
    ) {
        raise ValueError("Merchant, product, and evidence are required.");
    }
    if (
        candidate_input.price <= 0.0
        or candidate_input.shipping < 0.0
        or candidate_input.recurring_cost < 0.0
    ) {
        raise ValueError("Candidate prices must be valid non-negative amounts.");
    }
    target_candidate_id = stable_id(
        "candidate",
        f"{target_mission_id}|{candidate_input.merchant.upper().strip()}|{candidate_input.product.upper().strip()}|{round(
            candidate_input.price, 2
        ):.2f}"
    );
    existing: list[ShoppingCandidate] = [root-->[?:ShoppingCandidate, candidate_id==target_candidate_id]];
    if existing {
        return candidate_to_view(existing[0], mission.maximum_budget);
    }
    candidate = root ++> ShoppingCandidate(
        candidate_id=target_candidate_id,
        mission_id=target_mission_id,
        merchant=candidate_input.merchant.strip(),
        product=candidate_input.product.strip(),
        price=round(candidate_input.price, 2),
        shipping=round(candidate_input.shipping, 2),
        recurring_cost=round(candidate_input.recurring_cost, 2),
        product_url=candidate_input.product_url.strip(),
        evidence=candidate_input.evidence.strip(),
        created_at=now_iso()
    );
    candidate +>:CandidateFor:+> mission;
    mission.updated_at = now_iso();
    return candidate_to_view(candidate, mission.maximum_budget);
}

def:pub complete_shopping_mission(
    mission_id: str, agent_id: str
) -> ShoppingMissionView {
    target_mission_id = mission_id.strip();
    missions: list[ShoppingMission] = [root-->[?:ShoppingMission, mission_id==target_mission_id]];
    if not missions {
        raise ValueError("Shopping mission was not found.");
    }
    mission = missions[0];
    if mission.status == "READY_FOR_REVIEW" {
        return mission_to_view(mission);
    }
    if mission.status != "IN_PROGRESS" or mission.assigned_agent != agent_id.strip() {
        raise ValueError("Only the assigned agent can complete this shopping mission.");
    }
    candidates: list[ShoppingCandidate] = [root-->[?:ShoppingCandidate, mission_id==target_mission_id]];
    if not candidates {
        raise ValueError("Return at least one shopping candidate before completion.");
    }
    mission.status = "READY_FOR_REVIEW";
    mission.updated_at = now_iso();
    return mission_to_view(mission);
}

def active_subscription_total -> float {
    recurring_total: float = 0.0;
    for subscription in [root-->[?:Subscription]] {
        if subscription.status == "ACTIVE" or subscription.status == "PROTECTED" {
            recurring_total += subscription.monthly_cost;
        }
    }
    return round(recurring_total, 2);
}


def:pub propose_purchase(
    agent_id: str, merchant: str, purpose: str, amount: float, cadence: str
) -> PurchaseProposalView {
    normalized_agent = agent_id.strip() or "user";
    normalized_merchant = normalize_merchant(merchant);
    normalized_purpose = purpose.strip();
    normalized_cadence = cadence.upper().strip();
    if not normalized_merchant {
        raise ValueError("Merchant is required.");
    }
    if not normalized_purpose {
        raise ValueError("Purpose is required.");
    }
    monthly_cost = normalize_purchase_monthly_cost(amount, normalized_cadence);
    if normalized_cadence == "YEARLY" {
        normalized_cadence = "ANNUAL";
    }
    target_proposal_id = stable_id(
        "proposal",
        f"{normalized_agent}|{normalized_merchant}|{normalized_purpose.upper()}|{round(
            amount, 2
        ):.2f}|{normalized_cadence}"
    );
    plans: list[BudgetPlan] = [root-->[?:BudgetPlan]];
    projected = 0.0;
    outcome = "REVIEW";
    state = "AWAITING_APPROVAL";
    reason = "Configure and confirm a monthly budget before this purchase can be evaluated.";
    if plans {
        plan = plans[0];
        current_safe = calculate_safe_to_spend(
            plan.monthly_income,
            plan.fixed_obligations,
            active_subscription_total(),
            plan.safety_reserve
        );
        projected = round(current_safe - monthly_cost, 2);
        warning_floor = max(100.0, round(plan.safety_reserve * 0.25, 2));
        if projected < 0.0 {
            outcome = "BLOCK";
            state = "BLOCKED";
            reason = f"This purchase would exceed Safe to Spend by {0.0 - projected:.2f} per month.";
        } elif projected < warning_floor {
            outcome = "WARN";
            reason = f"This purchase leaves {projected:.2f} Safe to Spend, below the {warning_floor:.2f} warning floor.";
        } else {
            outcome = "SAFE";
            state = "PROPOSED";
            reason = f"This purchase leaves {projected:.2f} Safe to Spend per month.";
        }
    }
    existing: list[PurchaseProposal] = [root-->[?:PurchaseProposal, proposal_id==target_proposal_id]];
    if existing {
        existing_proposal = existing[0];
        existing_proposal.monthly_cost = monthly_cost;
        existing_proposal.projected_safe_to_spend = projected;
        existing_proposal.outcome = outcome;
        existing_proposal.reason = reason;
        if existing_proposal.state != "APPROVED"
        and existing_proposal.state != "SIMULATED"
        and existing_proposal.state != "REJECTED" {
            existing_proposal.state = state;
        }
        return proposal_to_view(existing_proposal);
    }
    agents: list[AgentIdentity] = [root-->[?:AgentIdentity, agent_id==normalized_agent]];
    agent: AgentIdentity;
    if agents {
        agent = agents[0];
    } else {
        agent = root ++> AgentIdentity(
            agent_id=normalized_agent,
            display_name=normalized_agent,
            created_at=now_iso()
        );
    }
    proposal = root ++> PurchaseProposal(
        proposal_id=target_proposal_id,
        agent_id=normalized_agent,
        merchant=normalized_merchant.title(),
        purpose=normalized_purpose,
        amount=round(amount, 2),
        cadence=normalized_cadence,
        monthly_cost=monthly_cost,
        projected_safe_to_spend=projected,
        outcome=outcome,
        state=state,
        reason=reason,
        created_at=now_iso()
    );
    proposal +>:ProposedBy:+> agent;
    return proposal_to_view(proposal);
}


def:pub decide_purchase_proposal(
    proposal_id: str, choice: str
) -> PurchaseProposalView {
    target_proposal_id = proposal_id;
    proposals: list[PurchaseProposal] = [root-->[?:PurchaseProposal, proposal_id==target_proposal_id]];
    if not proposals {
        raise ValueError("Purchase proposal was not found.");
    }
    proposal = proposals[0];
    normalized_choice = choice.upper().strip();
    if normalized_choice != "APPROVE" and normalized_choice != "REJECT" {
        raise ValueError("Choice must be APPROVE or REJECT.");
    }
    if proposal.state == "SIMULATED" or proposal.state == "REJECTED" {
        return proposal_to_view(proposal);
    }
    if normalized_choice == "APPROVE" {
        if proposal.outcome == "BLOCK" {
            proposal.state = "BLOCKED";
            return proposal_to_view(proposal);
        }
        if proposal.outcome == "REVIEW" {
            proposal.state = "AWAITING_APPROVAL";
            proposal.reason = "Configure and confirm a monthly budget before this purchase can be approved.";
            return proposal_to_view(proposal);
        }
        proposal.state = "APPROVED";
    } else {
        proposal.state = "REJECTED";
    }
    proposal.decided_at = now_iso();
    return proposal_to_view(proposal);
}


def:pub simulate_purchase(proposal_id: str) -> PurchaseProposalView {
    target_proposal_id = proposal_id;
    proposals: list[PurchaseProposal] = [root-->[?:PurchaseProposal, proposal_id==target_proposal_id]];
    if not proposals {
        raise ValueError("Purchase proposal was not found.");
    }
    proposal = proposals[0];
    if proposal.state == "APPROVED" {
        proposal.state = "SIMULATED";
    }
    return proposal_to_view(proposal);
}


def:pub save_budget_plan(
    monthly_income: float, fixed_obligations: float, safety_reserve: float
) -> BudgetView {
    if monthly_income <= 0.0 {
        raise ValueError("Monthly income must be greater than zero.");
    }
    if fixed_obligations < 0.0 or safety_reserve < 0.0 {
        raise ValueError("Obligations and safety reserve cannot be negative.");
    }
    plans: list[BudgetPlan] = [root-->[?:BudgetPlan]];
    timestamp = now_iso();
    plan: BudgetPlan;
    if plans {
        plan = plans[0];
        plan.monthly_income = round(monthly_income, 2);
        plan.fixed_obligations = round(fixed_obligations, 2);
        plan.safety_reserve = round(safety_reserve, 2);
        plan.confirmed_at = timestamp;
        plan.updated_at = timestamp;
    } else {
        plan = root ++> BudgetPlan(
            plan_id=stable_id("budget", "primary"),
            monthly_income=round(monthly_income, 2),
            fixed_obligations=round(fixed_obligations, 2),
            safety_reserve=round(safety_reserve, 2),
            confirmed_at=timestamp,
            updated_at=timestamp
        );
    }
    recurring_total = 0.0;
    for subscription in [root-->[?:Subscription]] {
        if subscription.status == "ACTIVE" {
            recurring_total += subscription.monthly_cost;
        }
    }
    safe_amount = calculate_safe_to_spend(
        plan.monthly_income,
        plan.fixed_obligations,
        recurring_total,
        plan.safety_reserve
    );
    budget_status = "SAFE";
    budget_warning = "";
    if safe_amount < 0.0 {
        budget_status = "UNSAFE";
        budget_warning = f"The confirmed plan exceeds monthly income by {0.0 - safe_amount:.2f}. Reduce obligations or the reserve before adding new spending.";
    }
    return BudgetView(
        configured=True,
        monthly_income=plan.monthly_income,
        fixed_obligations=plan.fixed_obligations,
        recurring_obligations=round(recurring_total, 2),
        safety_reserve=plan.safety_reserve,
        safe_to_spend=safe_amount,
        status=budget_status,
        warning=budget_warning,
        confirmed_at=plan.confirmed_at
    );
}


walker:pub ImportStatement {
    has csv_text: str = "",
        currency: str = "USD";

    can import_once with Root entry {
        preview = parse_statement_csv(self.csv_text, self.currency);
        if not preview.transactions {
            result = ImportResult(rejected=preview.rejected, currency=self.currency);
            report result;
            disengage;
        }
        existing: list[Statement] = [here-->[?:Statement, fingerprint==preview.statement_fingerprint]];
        if existing {
            result = ImportResult(
                statement_id=existing[0].statement_id,
                duplicate_count=len(preview.transactions),
                rejected=preview.rejected,
                debit_total=preview.debit_total,
                currency=preview.currency
            );
            report result;
            disengage;
        }
        statement_id = stable_id("statement", preview.statement_fingerprint);
        statement = here ++> Statement(
            statement_id=statement_id,
            fingerprint=preview.statement_fingerprint,
            currency=preview.currency,
            imported_at=now_iso(),
            debit_total=preview.debit_total,
            transaction_count=len(preview.transactions)
        );
        imported = 0;
        duplicates = 0;
        known_transactions: list[Transaction] = [here-->[?:Statement]->:Contains:->[?:Transaction]];
        for row in preview.transactions {
            duplicate = False;
            for known in known_transactions {
                if known.fingerprint == row.fingerprint {
                    duplicate = True;
                }
            }
            if duplicate {
                duplicates += 1;
                continue;
            }
            transaction = Transaction(
                transaction_id=row.fingerprint,
                fingerprint=row.fingerprint,
                date=row.date,
                description=row.description,
                amount=row.amount,
                currency=row.currency,
                category=row.category,
                subcategory=row.subcategory,
                account_name=row.account_name,
                account_mask=row.account_mask,
                transaction_type=row.transaction_type,
                payment_channel=row.payment_channel,
                city=row.city,
                region=row.region,
                country=row.country,
                pending=row.pending
            );
            statement +>:Contains:+> transaction;
            target_merchant_id = stable_id("merchant", row.merchant_name);
            merchants: list[Merchant] = [here-->[?:Merchant, merchant_id==target_merchant_id]];
            merchant: Merchant;
            if merchants {
                merchant = merchants[0];
            } else {
                merchant = here ++> Merchant(
                    merchant_id=target_merchant_id,
                    normalized_name=row.merchant_name,
                    display_name=row.merchant_name.title()
                );
            }
            transaction +>:PaidTo:+> merchant;
            imported += 1;
        }
        result = ImportResult(
            statement_id=statement_id,
            imported_count=imported,
            duplicate_count=duplicates,
            rejected=preview.rejected,
            debit_total=preview.debit_total,
            currency=preview.currency
        );
        report result;
    }
}


walker:pub AnalyzePortfolio {
    has updated_count: int = 0;

    can find_merchants with Root entry {
        visit [here-->[?:Merchant]];
    }

    can analyze with Merchant entry {
        transactions: list[Transaction] = [here<-:PaidTo:<-[?:Transaction]];
        points: list[PricePoint] = [];
        debits: list[Transaction] = [];
        for transaction in transactions {
            if transaction.amount < 0.0 {
                points.append(
                    PricePoint(date=transaction.date, amount=transaction.amount)
                );
                debits.append(transaction);
            }
        }
        detected = detect_recurrence(points);
        if not detected {
            skip;
        }
        sub_id = stable_id("subscription", here.merchant_id);
        existing: list[Subscription] = [root-->[?:Subscription, subscription_id==sub_id]];
        subscription: Subscription;
        if existing {
            subscription = existing[0];
            subscription.cadence = detected.cadence;
            subscription.monthly_cost = detected.monthly_cost;
            subscription.last_amount = detected.last_amount;
            subscription.next_expected = detected.next_expected;
            subscription.confidence = detected.confidence;
            subscription.price_change = detected.price_change;
            subscription.transaction_count = detected.transaction_count;
            subscription.analyzed_at = now_iso();
        } else {
            subscription = root ++> Subscription(
                subscription_id=sub_id,
                merchant_id=here.merchant_id,
                merchant_name=here.display_name,
                cadence=detected.cadence,
                monthly_cost=detected.monthly_cost,
                last_amount=detected.last_amount,
                next_expected=detected.next_expected,
                confidence=detected.confidence,
                price_change=detected.price_change,
                transaction_count=detected.transaction_count,
                analyzed_at=now_iso()
            );
        }
        for transaction in debits {
            linked: list[Subscription] = [transaction->:RecursAs:->[?:Subscription, subscription_id==sub_id]];
            if not linked {
                transaction +>:RecursAs(
                    match_confidence=detected.confidence
                ):+> subscription;
            }
        }
        self.updated_count += 1;
    }

    can finish with Root exit {
        report self.updated_count;
    }
}


def portfolio_family(merchant_name: str) -> str {
    name = merchant_name.upper();
    for token in ["NETFLIX", "HULU", "DISNEY", "SPOTIFY", "APPLE MUSIC", "YOUTUBE"] {
        if token in name {
            return "ENTERTAINMENT";
        }
    }
    for token in ["DROPBOX", "ICLOUD", "GOOGLE ONE", "ONEDRIVE"] {
        if token in name {
            return "CLOUD_STORAGE";
        }
    }
    return "OTHER";
}


walker:pub InvestigateSubscription {
    has subscription_id: str = "",
        created: bool = False;

    can locate with Root entry {
        visit [here-->[?:Subscription, subscription_id==self.subscription_id]];
    }

    can investigate with Subscription entry {
        target_case_id = stable_id(
            "case",
            f"{here.subscription_id}|{here.last_amount:.2f}|{here.transaction_count}"
        );
        existing: list[SubscriptionCase] = [root-->[?:SubscriptionCase, case_id==target_case_id]];
        if existing {
            report case_to_view(existing[0]);
            disengage;
        }
        evidence_ids: list[str] = [];
        linked_transactions: list[Transaction] = [here<-:RecursAs:<-[?:Transaction]];
        for transaction in linked_transactions {
            target_evidence_id = stable_id("evidence", transaction.transaction_id);
            evidence_nodes: list[Evidence] = [root-->[?:Evidence, evidence_id==target_evidence_id]];
            evidence: Evidence;
            if evidence_nodes {
                evidence = evidence_nodes[0];
            } else {
                evidence = root ++> Evidence(
                    evidence_id=target_evidence_id,
                    kind="CHARGE",
                    summary=f"{transaction.description} charged {0.0 - transaction.amount:.2f} {transaction.currency}",
                    amount=0.0 - transaction.amount,
                    occurred_at=transaction.date
                );
            }
            evidence_ids.append(target_evidence_id);
        }
        family = portfolio_family(here.merchant_name);
        overlap = 0;
        overlap_facts: list[str] = [];
        for candidate in [root-->[?:Subscription]] {
            if candidate.subscription_id != here.subscription_id
            and portfolio_family(candidate.merchant_name) == family
            and family != "OTHER" {
                overlap += 1;
                overlap_facts.append(
                    f"{candidate.merchant_name}: {candidate.monthly_cost:.2f} monthly equivalent"
                );
            }
        }
        recommendation = "REVIEW";
        confidence = here.confidence;
        reason = f"{here.merchant_name} is a confirmed {here.cadence.lower()} charge. Review whether it still earns its place.";
        if here.protected {
            recommendation = "KEEP";
            reason = "This subscription is protected by your saved preference.";
            confidence = 1.0;
        } elif overlap > 0 and here.confidence >= 0.8 {
            recommendation = "CANCEL";
            reason = f"SpendOS found {overlap} overlapping {family.lower().replace(
                '_', ' '
            )} subscription. Cancel only if this is the one you no longer want.";
        } elif here.price_change > 0.0 {
            recommendation = "DOWNGRADE";
            reason = f"The latest charge increased by {here.price_change:.2f}. Check for a lower plan before the next renewal.";
        }
        source = "deterministic";
        if live_agent_available() and not here.protected {
            charge_facts: list[str] = [];
            for transaction in linked_transactions {
                charge_facts.append(
                    f"{transaction.date}: {0.0 - transaction.amount:.2f} {transaction.currency} [{stable_id(
                        'evidence', transaction.transaction_id
                    )}]"
                );
            }
            price_facts: list[str] = [];
            if here.price_change != 0.0 {
                price_facts.append(f"Latest change: {here.price_change:.2f}");
            }
            preference_facts: list[str] = [];
            for preference in [root-->[?:Preference]] {
                if preference.merchant_id == here.merchant_id {
                    preference_facts.append(f"{preference.rule}={preference.value}");
                }
            }
            precedent_facts: list[str] = [];
            for precedent in [root-->[?:Precedent]] {
                if precedent.merchant_id == here.merchant_id {
                    precedent_facts.append(f"{precedent.outcome}: {precedent.reason}");
                }
            }
            packet = InvestigationPacket(
                merchant=here.merchant_name,
                cadence=here.cadence,
                monthly_cost=here.monthly_cost,
                confidence=here.confidence,
                evidence_ids=evidence_ids,
                charge_history=charge_facts,
                price_changes=price_facts,
                preferences=preference_facts,
                precedents=precedent_facts,
                portfolio_overlap=overlap_facts
            );
            try {
                assessment = assess_subscription(packet);
                allowed_outcomes = ["KEEP", "REVIEW", "DOWNGRADE", "CANCEL"];
                if assessment.recommendation in allowed_outcomes
                and citations_are_valid(assessment.evidence_ids, evidence_ids) {
                    recommendation = assessment.recommendation;
                    reason = assessment.reason;
                    confidence = min(here.confidence, assessment.confidence);
                    if confidence < 0.65 {
                        recommendation = "REVIEW";
                        reason = "The agent assessment was downgraded to review because confidence was low.";
                    }
                    source = "live agent";
                } else {
                    recommendation = "REVIEW";
                    reason = "The agent returned unsupported evidence, so SpendOS safely requires review.";
                    source = "agent output rejected";
                }
            } except Exception {
                source = "deterministic fallback";
            }
        }
        annual_savings = round(here.monthly_cost * 12.0, 2)
            if recommendation == "CANCEL"
            else 0.0;
        case_item = root ++> SubscriptionCase(
            case_id=target_case_id,
            subscription_id=here.subscription_id,
            merchant_name=here.merchant_name,
            recommendation=recommendation,
            reason=reason,
            annual_savings=annual_savings,
            confidence=confidence,
            evidence_ids=evidence_ids,
            source=source,
            created_at=now_iso()
        );
        case_item +>:CaseFor:+> here;
        for evidence in [root-->[?:Evidence]] {
            if evidence.evidence_id in evidence_ids {
                case_item +>:SupportedBy:+> evidence;
            }
        }
        self.created = True;
        report case_to_view(case_item);
        disengage;
    }
}


walker:pub DecideCase {
    has case_id: str = "",
        choice: str = "",
        note: str = "";

    can locate with Root entry {
        visit [here-->[?:SubscriptionCase, case_id==self.case_id]];
    }

    can decide with SubscriptionCase entry {
        normalized_choice = self.choice.upper();
        target_decision_id = stable_id(
            "decision", f"{here.case_id}|{normalized_choice}"
        );
        existing: list[Decision] = [root-->[?:Decision, decision_id==target_decision_id]];
        if existing {
            report existing[0].decision_id;
            disengage;
        }
        decision = root ++> Decision(
            decision_id=target_decision_id,
            case_id=here.case_id,
            choice=normalized_choice,
            decided_at=now_iso(),
            note=self.note
        );
        here +>:DecidedBy:+> decision;
        subscriptions: list[Subscription] = [here->:CaseFor:->[?:Subscription]];
        if subscriptions {
            subscription = subscriptions[0];
            if normalized_choice == "PROTECT" {
                subscription.protected = True;
                subscription.status = "PROTECTED";
                target_preference_id = stable_id(
                    "preference", f"{subscription.merchant_id}|PROTECT"
                );
                preferences: list[Preference] = [root-->[?:Preference, preference_id==target_preference_id]];
                if not preferences {
                    preference = root ++> Preference(
                        preference_id=target_preference_id,
                        merchant_id=subscription.merchant_id,
                        rule="NEVER_CANCEL",
                        value="true",
                        created_at=now_iso()
                    );
                    preference +>:AppliesTo:+> subscription;
                }
            }
            target_precedent_id = stable_id(
                "precedent", f"{subscription.merchant_id}|{normalized_choice}"
            );
            precedents: list[Precedent] = [root-->[?:Precedent, precedent_id==target_precedent_id]];
            precedent: Precedent;
            if precedents {
                precedent = precedents[0];
                precedent.hit_count += 1;
            } else {
                precedent = root ++> Precedent(
                    precedent_id=target_precedent_id,
                    merchant_id=subscription.merchant_id,
                    outcome=normalized_choice,
                    reason=self.note or f"User chose {normalized_choice}.",
                    created_at=now_iso()
                );
            }
            decision +>:Establishes:+> precedent;
            if normalized_choice == "APPROVE_CANCEL"
            and here.recommendation == "CANCEL" {
                target_action_id = stable_id("action", here.case_id);
                actions: list[SimulatedAction] = [root-->[?:SimulatedAction, action_id==target_action_id]];
                if not actions {
                    action = root ++> SimulatedAction(
                        action_id=target_action_id,
                        case_id=here.case_id,
                        merchant_name=here.merchant_name,
                        state="APPROVED",
                        annual_savings=here.annual_savings,
                        approved_at=now_iso()
                    );
                    action +>:ActsOn:+> here;
                }
                here.state = "APPROVED";
            } elif normalized_choice == "KEEP" or normalized_choice == "PROTECT" {
                here.state = "CLOSED";
            } else {
                here.state = "POSTPONED";
            }
        }
        report decision.decision_id;
        disengage;
    }
}


walker:pub SimulateCancellation {
    has action_id: str = "";

    can locate with Root entry {
        visit [here-->[?:SimulatedAction, action_id==self.action_id]];
    }

    can simulate with SimulatedAction entry {
        if here.state == "APPROVED" {
            here.state = "SIMULATED";
            here.simulated_at = now_iso();
            cases: list[SubscriptionCase] = [here->:ActsOn:->[?:SubscriptionCase]];
            if cases {
                cases[0].state = "SIMULATED";
            }
        }
        report action_to_view(here);
        disengage;
    }
}


def cart_line_to_view(line: CartLine) -> CartLineView {
    return CartLineView(
        product_id=line.product_id,
        name=line.name,
        brand=line.brand,
        size=line.size,
        unit_price=line.unit_price,
        quantity=line.quantity,
        line_total=round(line.unit_price * line.quantity, 2),
        currency=line.currency
    );
}

def find_cart(store: str) -> Cart | None {
    target = store.strip().lower();
    for cart in [root-->[?:Cart]] {
        if cart.store.strip().lower() == target {
            return cart;
        }
    }
    return None;
}

def cart_view_from(store: str, lines: list[CartLineView]) -> CartView {
    totals = compute_cart_totals(lines);
    currency = lines[0].currency if lines else "USD";
    return CartView(
        store=store,
        lines=lines,
        subtotal=totals.subtotal,
        fees=totals.fees,
        taxes=totals.taxes,
        grand_total=totals.grand_total,
        currency=currency
    );
}


def:pub resolve_products(store: str, query: str) -> list[CatalogProductView] {
    return search_catalog(store, query);
}


def:pub add_to_cart(store: str, product_id: str, quantity: float) -> CartView {
    normalized_store = store.strip();
    normalized_product_id = product_id.strip();
    if not normalized_store {
        raise ValueError("Store is required.");
    }
    if not normalized_product_id {
        raise ValueError("Product id is required.");
    }
    if quantity <= 0.0 {
        raise ValueError("Quantity must be greater than zero.");
    }
    catalog_matches: list[CatalogProductView] = [
        product
        for product in search_catalog(normalized_store, normalized_product_id)
        if product.product_id == normalized_product_id
    ];
    if not catalog_matches {
        raise ValueError(
            f"Product {normalized_product_id} was not found at {normalized_store}."
        );
    }
    product = catalog_matches[0];
    if not product.in_stock {
        raise ValueError(f"{product.name} is out of stock at {normalized_store}.");
    }
    cart = find_cart(normalized_store);
    if not cart {
        cart = root ++> Cart(
            cart_id=stable_id("cart", normalized_store.upper()),
            store=normalized_store,
            created_at=now_iso(),
            updated_at=now_iso()
        );
    }
    existing_lines: list[CartLine] = [cart->:Holds:->[?:CartLine, product_id==normalized_product_id]];
    if existing_lines {
        existing_lines[0].quantity = round(existing_lines[0].quantity + quantity, 2);
    } else {
        line = CartLine(
            line_id=stable_id("cartline", f"{cart.cart_id}|{normalized_product_id}"),
            product_id=product.product_id,
            name=product.name,
            brand=product.brand,
            size=product.size,
            unit_price=product.price,
            quantity=round(quantity, 2),
            currency=product.currency
        );
        cart +>:Holds:+> line;
    }
    cart.updated_at = now_iso();
    return view_cart(normalized_store);
}


def:pub view_cart(store: str) -> CartView {
    normalized_store = store.strip();
    cart = find_cart(normalized_store);
    if not cart {
        return CartView(store=normalized_store);
    }
    lines: list[CartLine] = [cart->:Holds:->[?:CartLine]];
    line_views = [cart_line_to_view(line) for line in lines];
    line_views = sorted(line_views, key=lambda (item: CartLineView) { item.name; });
    return cart_view_from(normalized_store, line_views);
}


def:pub simulate_order(store: str) -> SimulatedOrderView {
    normalized_store = store.strip();
    cart = find_cart(normalized_store);
    if not cart {
        raise ValueError(
            f"No cart exists for {normalized_store}. Add items before simulating an order."
        );
    }
    lines: list[CartLine] = [cart->:Holds:->[?:CartLine]];
    if not lines {
        raise ValueError(
            f"The cart for {normalized_store} is empty. Add items before simulating an order."
        );
    }
    line_views = [cart_line_to_view(line) for line in lines];
    totals = compute_cart_totals(line_views);
    currency = line_views[0].currency if line_views else "USD";
    created = now_iso();
    order_id = stable_id("order", f"{cart.cart_id}|{created}");
    order = root ++> PurchaseOrder(
        order_id=order_id,
        store=normalized_store,
        subtotal=totals.subtotal,
        fees=totals.fees,
        taxes=totals.taxes,
        grand_total=totals.grand_total,
        currency=currency,
        status="SIMULATED",
        created_at=created
    );
    for line in lines {
        order_line = OrderLine(
            line_id=line.line_id,
            product_id=line.product_id,
            name=line.name,
            brand=line.brand,
            size=line.size,
            unit_price=line.unit_price,
            quantity=line.quantity,
            line_total=round(line.unit_price * line.quantity, 2),
            currency=line.currency
        );
        order +>:Included:+> order_line;
        del line;
    }
    return SimulatedOrderView(
        order_id=order.order_id,
        store=order.store,
        lines=line_views,
        subtotal=order.subtotal,
        fees=order.fees,
        taxes=order.taxes,
        grand_total=order.grand_total,
        currency=order.currency,
        status=order.status,
        created_at=order.created_at
    );
}


def:pub record_audit(entry_text: str) -> str {
    normalized_entry = entry_text.strip();
    if not normalized_entry {
        raise ValueError("Audit entry text is required.");
    }
    created = now_iso();
    audit_id = stable_id("audit", f"{normalized_entry}|{created}");
    root ++> AuditEntry(audit_id=audit_id, entry=normalized_entry, created_at=created);
    return audit_id;
}


def:pub place_purchase(
    instruction: str, default_store: str = "Instacart"
) -> PurchaseResultView {
    parsed = parse_purchase_instruction(instruction, default_store);
    notes: list[str] = [note for note in parsed.notes];
    unresolved: list[str] = [];
    resolved: list[ResolvedPurchaseLine] = [];
    for item in parsed.items {
        candidates = resolve_products(parsed.store, item.query);
        if not candidates {
            unresolved.append(
                f"No catalog match for '{item.raw_text}' at {parsed.store}."
            );
            continue;
        }
        best = candidates[0];
        if not best.in_stock {
            unresolved.append(
                f"{best.name} ({best.size}) is currently out of stock at {parsed.store}. Tell SpendOS whether to skip it or name a different item."
            );
            continue;
        }
        resolved.append(
            ResolvedPurchaseLine(
                raw_text=item.raw_text,
                product_id=best.product_id,
                quantity=item.quantity,
                quantity_assumed=item.quantity_assumed
            )
        );
    }
    if unresolved {
        return PurchaseResultView(
            status="NEEDS_INPUT",
            store=parsed.store,
            notes=notes,
            unresolved_items=unresolved
        );
    }
    for line in resolved {
        add_to_cart(parsed.store, line.product_id, line.quantity);
        if line.quantity_assumed {
            notes.append(f"Assumed quantity 1 for '{line.raw_text}'.");
        }
    }
    cart = view_cart(parsed.store);
    if not cart.lines {
        return PurchaseResultView(
            status="NEEDS_INPUT",
            store=parsed.store,
            notes=notes,
            unresolved_items=["No items could be added to the cart from this instruction."]
        );
    }
    order = simulate_order(parsed.store);
    record_audit(
        f"ORDER {order.order_id} at {order.store}: {len(order.lines)} item(s), grand total {order.grand_total:.2f} {order.currency}, status {order.status}. No real charge was made."
    );
    return PurchaseResultView(
        status="SIMULATED",
        store=parsed.store,
        order=order,
        notes=notes,
        unresolved_items=[]
    );
}


def:pub reset_demo_data -> str {
    for node_item in [root-->] {
        del node_item;
    }
    return "reset";
}
