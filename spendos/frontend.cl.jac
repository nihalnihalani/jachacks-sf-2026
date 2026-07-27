"""SpendOS Subscription Guardian client."""

import "./styles/spendos.css";

sv import from endpoints {
    ActionView,
    AnalyzePortfolio,
    BudgetView,
    CategorySpendView,
    CaseView,
    Dashboard,
    Decision,
    DecideCase,
    ImportPreview,
    ImportResult,
    ImportStatement,
    InvestigateSubscription,
    MerchantSpendView,
    PurchaseProposalView,
    SimulatedAction,
    SimulateCancellation,
    ShoppingMissionView,
    SpendingAnalytics,
    SubscriptionCase,
    SubscriptionView,
    TransactionView,
    decide_purchase_proposal,
    create_shopping_mission,
    get_dashboard,
    get_synthetic_feed,
    preview_statement,
    propose_purchase,
    reset_demo_data,
    save_budget_plan,
    simulate_purchase,
}

glob SAMPLE_CSV: str = """date,description,amount
2025-01-05,Netflix.com,-22.99
2025-02-05,NETFLIX.COM 9832,-22.99
2025-03-05,Netflix recurring,-24.99
2025-01-12,Disney Plus,-15.99
2025-02-12,DISNEY PLUS,-15.99
2025-03-12,Disney Plus recurring,-15.99
2025-01-18,Dropbox Plus,-19.99
2025-02-18,DROPBOX PLUS,-19.99
2025-03-18,Dropbox Plus,-19.99
2025-03-21,Neighborhood Market,-84.32
not-a-date,Broken row,-9.00""";

obj AgentActivityEvent {
    has id: int,
        time: str,
        tool: str,
        phase: str,
        title: str,
        detail: str,
        status: str;
}


def money(value: float, currency: str = "USD") -> str {
    symbol = "$" if currency == "USD" else currency + " ";
    return (f"-{symbol}{0.0 - value:.2f}" if value < 0.0 else f"{symbol}{value:.2f}");
}


def:pub Metric(label: str, value: str, detail: str) -> JsxElement {
    return
        <div className="metric">
            <div className="metric-label">{label}</div>
            <div className="metric-value">{value}</div>
            <div className="metric-detail">{detail}</div>
        </div>;
}


def:pub StatusPill(label: str, tone: str = "neutral") -> JsxElement {
    return <span className={"pill pill-" + tone}>{label}</span>;
}

def:pub FeedTransactionRow(transaction: TransactionView, currency: str) -> JsxElement {
    account_label: str = transaction.account_name;
    if transaction.account_mask {
        account_label = account_label + " ••" + transaction.account_mask;
    }
    return
        <article className="feed-transaction">
            <div
                className={"feed-direction feed-credit"
                    if transaction.amount > 0.0
                    else "feed-direction"}
            >
                {"↙" if transaction.amount > 0.0 else "↗"}
            </div>
            <div className="feed-transaction-main">
                <div>
                    <strong>{transaction.merchant}</strong>
                    {transaction.pending and <StatusPill label="Pending" tone="warn"/>}
                </div>
                <span>
                    {transaction.category}{transaction.subcategory
                    and " · " + transaction.subcategory}
                </span>
            </div>
            <div className="feed-transaction-context">
                <strong>{account_label}</strong>
                <span>
                    {transaction.payment_channel}{transaction.location
                    and " · " + transaction.location}
                </span>
            </div>
            <div
                className={"feed-amount feed-amount-credit"
                    if transaction.amount > 0.0
                    else "feed-amount"}
            >
                {money(transaction.amount, currency)}
            </div>
        </article>;
}


def:pub LiveFeedPanel(
    dashboard: Dashboard,
    progress: int,
    total: int,
    running: bool,
    events: list[str],
    onStart: Callable[[], None],
    onToggle: Callable[[], None],
) -> JsxElement {
    percent: int = int((float(progress) / float(total)) * 100.0) if total > 0 else 0;
    return
        <div className="feed-layout">
            <section className="feed-control-card">
                <div className="feed-control-top">
                    <div>
                        <div className="eyebrow">Synthetic connected account</div>
                        <h2>Live bank feed</h2>
                    </div>
                    <StatusPill
                        label={"Streaming"
                            if running
                            else (
                                "Complete"
                                    if total > 0 and progress >= total
                                    else "Ready"
                            )}
                        tone={"safe"
                            if running or (total > 0 and progress >= total)
                            else "neutral"}
                    />
                </div>
                <p>
                    Streams realistic checking and card activity into the graph in small batches. SpendOS re-runs subscription and budget analysis after every arrival.
                </p>
                <div
                    className="feed-progress"
                    role="progressbar"
                    aria-valuemin="0"
                    aria-valuemax={str(total)}
                    aria-valuenow={str(progress)}
                >
                    <div style={{"width": str(percent) + "%"}}/>
                </div>
                <div className="feed-progress-label">
                    <strong>{progress} of {total} transactions</strong>
                    <span>{percent}% analyzed</span>
                </div>
                <div className="button-row">
                    <button className="button button-primary" onClick={onStart}>
                        {("Restart feed" if total > 0 else "Start live feed")}
                    </button>
                    {total > 0
                    and progress < total
                    and <button className="button button-secondary" onClick={onToggle}>
                        {"Pause" if running else "Resume"}
                    </button>}
                </div>
                <small>
                    Simulation only. No bank is connected and no external action is performed.
                </small>
            </section>
            <section className="feed-activity-card" aria-live="polite">
                <div className="section-heading">
                    <div>
                        <h2>Guardian activity</h2>
                        <p>Every entry is produced by the current feed run.</p>
                    </div>
                    <span
                        className={"live-indicator live-indicator-on"
                            if running
                            else "live-indicator"}
                    >
                        <span className="live-dot"/>{" "}
                        {("Live" if running else "Idle")}
                    </span>
                </div>
                {not events
                and <div className="preview-empty">
                    Start the feed to watch the graph analyze new activity.
                </div>}
                {events
                and <div className="feed-event-list">
                    {for (index, event) in enumerate(events) {
                        <div key={str(index)}>
                            <span>✓</span>
                            {event}
                        </div>
                    }}
                </div>}
            </section>
            <section className="feed-stream-card">
                <div className="section-heading">
                    <div>
                        <h2>Latest account activity</h2>
                        <p>
                            Detailed normalized transactions read back from the Jac graph.
                        </p>
                    </div>
                    <strong>{dashboard.transaction_count} total</strong>
                </div>
                {not dashboard.recent_transactions
                and <div className="empty-inline">
                    Waiting for the first bank event.
                </div>}
                <div className="feed-transaction-list">
                    {for transaction in dashboard.recent_transactions {
                        <FeedTransactionRow
                            key={transaction.transaction_id}
                            transaction={transaction}
                            currency={dashboard.currency}
                        />
                    }}
                </div>
            </section>
        </div>;
}


def:pub SubscriptionRow(
    subscription: SubscriptionView, currency: str, onInvestigate: Callable[[str], None]
) -> JsxElement {
    def investigate(e: MouseEvent) {
        onInvestigate(subscription.subscription_id);
    }
    cadence = subscription.cadence.lower().title();
    return
        <article className="subscription-row">
            <div className="merchant-avatar">{subscription.merchant[0:1]}</div>
            <div className="subscription-main">
                <div className="subscription-title">
                    <strong>{subscription.merchant}</strong>
                    {subscription.protected
                    and <StatusPill label="Protected" tone="safe"/>}
                    {subscription.price_change > 0.0
                    and <StatusPill
                        label={"+" + money(subscription.price_change, currency)}
                        tone="warn"
                    />}
                </div>
                <div className="subscription-meta">
                    {cadence} · {subscription.transaction_count} matching charges · {int(
                        subscription.confidence * 100.0
                    )}% confidence
                </div>
            </div>
            <div className="subscription-next">
                <strong>{money(subscription.monthly_cost, currency)}</strong>
                <span>monthly equivalent</span>
            </div>
            <div className="subscription-date">
                <strong>{subscription.next_expected}</strong>
                <span>next expected</span>
            </div>
            <button className="button button-secondary" onClick={investigate}>
                Investigate
            </button>
        </article>;
}


def:pub CaseCard(
    caseItem: CaseView, currency: str, onDecision: Callable[[str, str], None]
) -> JsxElement {
    def keep(e: MouseEvent) {
        onDecision(caseItem.case_id, "KEEP");
    }
    def protect(e: MouseEvent) {
        onDecision(caseItem.case_id, "PROTECT");
    }
    def postpone(e: MouseEvent) {
        onDecision(caseItem.case_id, "POSTPONE");
    }
    def approve(e: MouseEvent) {
        onDecision(caseItem.case_id, "APPROVE_CANCEL");
    }
    tone = "danger"
        if caseItem.recommendation == "CANCEL"
        else (
            "warn"
                if caseItem.recommendation == "DOWNGRADE"
                else ("safe" if caseItem.recommendation == "KEEP" else "neutral")
        );
    return
        <article className="case-card">
            <div className="case-top">
                <div>
                    <div className="eyebrow">Guardian finding</div>
                    <h3>{caseItem.merchant}</h3>
                </div>
                <StatusPill label={caseItem.recommendation} tone={tone}/>
            </div>
            <p>{caseItem.reason}</p>
            <div className="evidence-line">
                <span>{len(caseItem.evidence_ids)} cited charges</span>
                <span>{int(caseItem.confidence * 100.0)}% confidence</span>
                <span>{caseItem.source}</span>
                {caseItem.annual_savings > 0.0
                and <span>
                    {money(caseItem.annual_savings, currency)} potential annual savings
                </span>}
            </div>
            {caseItem.state == "OPEN"
            and <div className="case-actions">
                <button className="button button-quiet" onClick={keep}>Keep</button>
                <button className="button button-quiet" onClick={protect}>
                    Always protect
                </button>
                <button className="button button-quiet" onClick={postpone}>
                    Later
                </button>
                {caseItem.recommendation == "CANCEL"
                and <button className="button button-danger" onClick={approve}>
                    Approve simulated cancellation
                </button>}
            </div>}
            {caseItem.state != "OPEN"
            and <StatusPill label={caseItem.state} tone="safe"/>}
        </article>;
}


def:pub ActionCard(
    action: ActionView, currency: str, onSimulate: Callable[[str], None]
) -> JsxElement {
    def simulate(e: MouseEvent) {
        onSimulate(action.action_id);
    }
    return
        <article className="action-card">
            <div>
                <div className="eyebrow">Controlled action</div>
                <h3>{action.merchant}</h3>
                <p>Expected annual savings: {money(action.annual_savings, currency)}</p>
            </div>
            <div className="action-state">
                <StatusPill
                    label={action.state}
                    tone={"safe" if action.state == "SIMULATED" else "warn"}
                />
                {action.state == "APPROVED"
                and <button className="button button-primary" onClick={simulate}>
                    Run simulation
                </button>}
            </div>
            <div className="disclosure">No external action was performed.</div>
        </article>;
}


def:pub ImportPreviewPanel(
    preview: ImportPreview, busy: bool, onCommit: Callable[[], None]
) -> JsxElement {
    return
        <div>
            <div className="preview-total">
                <span>Valid transactions</span>
                <strong>{len(preview.transactions)}</strong>
            </div>
            <div className="preview-total">
                <span>Total debits</span>
                <strong>{money(preview.debit_total, preview.currency)}</strong>
            </div>
            <div className="preview-total">
                <span>Rejected rows</span>
                <strong>{len(preview.rejected)}</strong>
            </div>
            {preview.rejected
            and <div className="rejections">
                {for rejected in preview.rejected {
                    <div key={str(rejected.row_number)}>
                        <strong>Row {rejected.row_number}</strong>
                        <span>{rejected.reason}</span>
                    </div>
                }}
            </div>}
            <button
                className="button button-primary button-full"
                disabled={busy or not preview.transactions}
                onClick={onCommit}
            >
                Import and analyze
            </button>
        </div>;
}

def:pub BudgetGuard(
    budget: BudgetView,
    currency: str,
    busy: bool,
    onSave: Callable[[float, float, float], None]
) -> JsxElement {
    has incomeText: str = (str(budget.monthly_income) if budget.configured else ""),
        fixedText: str = (str(budget.fixed_obligations) if budget.configured else ""),
        reserveText: str = (str(budget.safety_reserve) if budget.configured else ""),
        formError: str = "";

    def edit_income(e: ChangeEvent) {
        incomeText = e.target.value;
        formError = "";
    }
    def edit_fixed(e: ChangeEvent) {
        fixedText = e.target.value;
        formError = "";
    }
    def edit_reserve(e: ChangeEvent) {
        reserveText = e.target.value;
        formError = "";
    }
    def submit(e: FormEvent) {
        e.preventDefault();
        try {
            income = float(incomeText);
            fixed = float(fixedText or "0");
            reserve = float(reserveText or "0");
            if income <= 0.0 or fixed < 0.0 or reserve < 0.0 {
                formError = "Enter a positive income and non-negative obligations.";
            } else {
                onSave(income, fixed, reserve);
            }
        } except Exception {
            formError = "Use valid numeric amounts.";
        }
    }

    return
        <div className="budget-layout">
            <form className="budget-card" onSubmit={submit}>
                <div className="step-label">Your confirmed plan</div>
                <h2>Set the monthly guardrails</h2>
                <p>
                    SpendOS subtracts fixed costs, detected subscriptions, and your safety reserve. It never guesses your income.
                </p>
                <label>
                    <span>Monthly take-home income</span>
                    <input
                        type="number"
                        min="0"
                        step="0.01"
                        value={incomeText}
                        onChange={edit_income}
                        placeholder="5000"
                    />
                </label>
                <label>
                    <span>Fixed obligations</span>
                    <small>Rent, debt payments, utilities, and other essentials.</small>
                    <input
                        type="number"
                        min="0"
                        step="0.01"
                        value={fixedText}
                        onChange={edit_fixed}
                        placeholder="2500"
                    />
                </label>
                <label>
                    <span>Safety reserve</span>
                    <small>Money SpendOS must leave untouched this month.</small>
                    <input
                        type="number"
                        min="0"
                        step="0.01"
                        value={reserveText}
                        onChange={edit_reserve}
                        placeholder="500"
                    />
                </label>
                {formError
                and <div className="notice notice-error" role="alert">{formError}</div>}
                <button className="button button-primary" disabled={busy} type="submit">
                    Confirm budget
                </button>
            </form>
            <div
                className={"safe-card safe-card-danger"
                    if budget.configured and budget.status == "UNSAFE"
                    else "safe-card"}
            >
                <div className="step-label">Budget Guard</div>
                <span>Safe to Spend</span>
                <strong>
                    {money(budget.safe_to_spend, currency)
                        if budget.configured
                        else "Not configured"}
                </strong>
                {budget.configured
                and <div className="budget-breakdown">
                    <div>
                        <span>Income</span>
                        <strong>{money(budget.monthly_income, currency)}</strong>
                    </div>
                    <div>
                        <span>Fixed obligations</span>
                        <strong>-{money(budget.fixed_obligations, currency)}</strong>
                    </div>
                    <div>
                        <span>Subscriptions</span>
                        <strong>
                            -{money(budget.recurring_obligations, currency)}
                        </strong>
                    </div>
                    <div>
                        <span>Safety reserve</span>
                        <strong>-{money(budget.safety_reserve, currency)}</strong>
                    </div>
                </div>}
                {budget.configured
                and budget.status == "SAFE"
                and <div className="safe-message">
                    Your confirmed plan can absorb current recurring charges.
                </div>}
                {budget.warning
                and <div className="unsafe-message" role="alert">{budget.warning}</div>}
                <small>
                    Deterministic monthly estimate. SpendOS does not move money.
                </small>
            </div>
        </div>;
}

def:pub PurchaseProposalCard(
    proposal: PurchaseProposalView,
    currency: str,
    busy: bool,
    onDecision: Callable[[str, str], None],
    onSimulate: Callable[[str], None],
) -> JsxElement {
    def approve(_e: MouseEvent) {
        onDecision(proposal.proposal_id, "APPROVE");
    }
    def reject(_e: MouseEvent) {
        onDecision(proposal.proposal_id, "REJECT");
    }
    def simulate_purchase(_e: MouseEvent) {
        onSimulate(proposal.proposal_id);
    }
    tone = (
        "danger"
            if proposal.outcome == "BLOCK"
            else ("warn" if proposal.outcome in ["WARN", "REVIEW"] else "safe")
    );
    return
        <article className="proposal-card">
            <div className="proposal-top">
                <div>
                    <div className="eyebrow">Proposed by {proposal.agent_id}</div>
                    <h3>{proposal.merchant}</h3>
                    <p>{proposal.purpose}</p>
                </div>
                <StatusPill label={proposal.outcome} tone={tone}/>
            </div>
            <div className="proposal-impact">
                <div>
                    <span>Proposed cost</span>
                    <strong>
                        {money(proposal.amount, currency)} / {proposal.cadence.lower()}
                    </strong>
                </div>
                <div>
                    <span>Monthly equivalent</span>
                    <strong>{money(proposal.monthly_cost, currency)}</strong>
                </div>
                <div>
                    <span>Projected Safe to Spend</span>
                    <strong>{money(proposal.projected_safe_to_spend, currency)}</strong>
                </div>
            </div>
            <p className="proposal-reason">{proposal.reason}</p>
            <div className="proposal-footer">
                <StatusPill
                    label={proposal.state}
                    tone={"safe"
                        if proposal.state in ["APPROVED", "SIMULATED"]
                        else "neutral"}
                />
                <div className="button-row">
                    {proposal.state in ["PROPOSED", "AWAITING_APPROVAL", "BLOCKED"]
                    and <button
                        className="button button-quiet"
                        disabled={busy}
                        onClick={reject}
                    >
                        Reject
                    </button>}{proposal.state in ["PROPOSED", "AWAITING_APPROVAL"]
                    and proposal.outcome != "BLOCK"
                    and <button
                        className="button button-primary"
                        disabled={busy}
                        onClick={approve}
                    >
                        Approve
                    </button>}{proposal.state == "APPROVED"
                    and <button
                        className="button button-primary"
                        disabled={busy}
                        onClick={simulate_purchase}
                    >
                        Simulate purchase
                    </button>}
                </div>
            </div>
            {proposal.outcome == "BLOCK"
            and proposal.state == "BLOCKED"
            and <div className="blocked-note" role="alert">
                SpendOS blocked approval because this proposal violates your budget guardrails.
            </div>}
            <div className="disclosure">No purchase occurred.</div>
        </article>;
}


def:pub PurchaseGuard(
    proposals: list[PurchaseProposalView],
    currency: str,
    budget: BudgetView,
    busy: bool,
    onPropose: Callable[[str, str, str, float, str], None],
    onDecision: Callable[[str, str], None],
    onSimulate: Callable[[str], None],
) -> JsxElement {
    has agentId: str = "hermes",
        merchant: str = "",
        purpose: str = "",
        amountText: str = "",
        cadence: str = "MONTHLY",
        formError: str = "";

    def edit_agent(e: ChangeEvent) {
        agentId = e.target.value;
        formError = "";
    }
    def edit_merchant(e: ChangeEvent) {
        merchant = e.target.value;
        formError = "";
    }
    def edit_purpose(e: ChangeEvent) {
        purpose = e.target.value;
        formError = "";
    }
    def edit_amount(e: ChangeEvent) {
        amountText = e.target.value;
        formError = "";
    }
    def edit_cadence(e: ChangeEvent) {
        cadence = e.target.value;
    }
    def submit(e: FormEvent) {
        e.preventDefault();
        try {
            amount = float(amountText);
            if not agentId.strip() or not merchant.strip() or not purpose.strip() {
                formError = "Agent, merchant, and purpose are required.";
            } elif amount <= 0.0 {
                formError = "Enter a purchase amount greater than zero.";
            } else {
                onPropose(
                    agentId.strip(), merchant.strip(), purpose.strip(), amount, cadence
                );
            }
        } except Exception {
            formError = "Enter a valid purchase amount.";
        }
    }

    return
        <div className="purchase-layout">
            <form className="purchase-form" onSubmit={submit}>
                <div className="step-label">Agent purchase preflight</div>
                <h2>Check before an agent spends</h2>
                <p>
                    SpendOS evaluates every proposal against your confirmed budget. Approval is explicit and execution is simulated.
                </p>
                <div className="form-grid">
                    <label>
                        <span>Agent ID</span>
                        <input
                            value={agentId}
                            onChange={edit_agent}
                            placeholder="hermes"
                            autoComplete="off"
                        />
                    </label>
                    <label>
                        <span>Merchant</span>
                        <input
                            value={merchant}
                            onChange={edit_merchant}
                            placeholder="Developer Cloud"
                            autoComplete="organization"
                        />
                    </label>
                    <label className="field-wide">
                        <span>Purpose</span>
                        <input
                            value={purpose}
                            onChange={edit_purpose}
                            placeholder="Why does the agent need this?"
                        />
                    </label>
                    <label>
                        <span>Amount</span>
                        <input
                            type="number"
                            min="0.01"
                            step="0.01"
                            value={amountText}
                            onChange={edit_amount}
                            placeholder="15.00"
                        />
                    </label>
                    <label>
                        <span>Cadence</span>
                        <select value={cadence} onChange={edit_cadence}>
                            <option value="ONE_TIME">One time</option>
                            <option value="MONTHLY">Monthly</option>
                            <option value="QUARTERLY">Quarterly</option>
                            <option value="ANNUAL">Annual</option>
                        </select>
                    </label>
                </div>
                {not budget.configured
                and <div className="notice notice-error" role="alert">
                    Configure Budget Guard before evaluating purchases.
                </div>}
                {formError
                and <div className="notice notice-error" role="alert">{formError}</div>}
                <button
                    className="button button-primary"
                    type="submit"
                    disabled={busy or not budget.configured}
                >
                    Run preflight
                </button>
                <small>
                    A SAFE result is not permission. SpendOS requires your approval.
                </small>
            </form>
            <section className="approval-inbox" aria-labelledby="approval-inbox-title">
                <div className="section-heading">
                    <div>
                        <div className="step-label">Approval inbox</div>
                        <h2 id="approval-inbox-title">Agent proposals</h2>
                        <p>Review the budget impact and reasoning before deciding.</p>
                    </div>
                    <StatusPill label={str(len(proposals)) + " total"}/>
                </div>
                {not proposals
                and <div className="empty-inline">
                    No purchase proposals yet. Run a preflight to create one.
                </div>}
                <div className="proposal-list">
                    {for proposal in proposals {
                        <PurchaseProposalCard
                            key={proposal.proposal_id}
                            proposal={proposal}
                            currency={currency}
                            busy={busy}
                            onDecision={onDecision}
                            onSimulate={onSimulate}
                        />
                    }}
                </div>
            </section>
        </div>;
}

def:pub HomeScreen(
    dashboard: Dashboard,
    onFeed: Callable[[], None],
    onBudget: Callable[[MouseEvent], None],
    onImport: Callable[[MouseEvent], None],
    onAgent: Callable[[MouseEvent], None],
) -> JsxElement {
    pending_approvals: int = len(
        [
            proposal
            for proposal in dashboard.proposals
            if proposal.state in ["PROPOSED", "AWAITING_APPROVAL"]
        ]
    );
    attention_count: int = len(dashboard.spending.uncategorized) + pending_approvals;
    return
        <section className="money-screen">
            {attention_count > 0
            and <button className="attention-banner" onClick={onAgent}>
                <span>Guardian found {attention_count} items that need attention</span>
                <strong>Review →</strong>
            </button>}
            <div className="hero-finance-card">
                <div className="hero-card-top">
                    <div>
                        <span>Safe to spend</span>
                        <strong>
                            {money(dashboard.budget.safe_to_spend, dashboard.currency)
                                if dashboard.budget.configured
                                else "Set your guardrails"}
                        </strong>
                    </div>
                    <StatusPill
                        label={"Protected"
                            if dashboard.budget.configured
                            else "Setup needed"}
                        tone={"safe" if dashboard.budget.configured else "warn"}
                    />
                </div>
                <div className="spend-trend" aria-label="Current spending summary">
                    <div style={{"height": "24%"}}/>
                    <div style={{"height": "38%"}}/>
                    <div style={{"height": "34%"}}/>
                    <div style={{"height": "62%"}}/>
                    <div style={{"height": "54%"}}/>
                    <div style={{"height": "78%"}}/>
                    <div style={{"height": "68%"}}/>
                </div>
                <div className="hero-card-footer">
                    <div>
                        <span>
                            Spent in {dashboard.spending.period or "latest month"}
                        </span>
                        <strong>
                            {money(dashboard.spending.total_spend, dashboard.currency)}
                        </strong>
                    </div>
                    <div>
                        <span>Recurring monthly</span>
                        <strong>
                            {money(dashboard.monthly_total, dashboard.currency)}
                        </strong>
                    </div>
                </div>
            </div>
            <div className="guardian-brief">
                <div className="section-heading">
                    <div>
                        <div className="step-label">Always-on guardian</div>
                        <h2>What matters today</h2>
                    </div>
                    <StatusPill label="Hermes connected" tone="safe"/>
                </div>
                <div className="brief-list">
                    <button onClick={onAgent}>
                        <span className="row-icon agent-icon">A</span>
                        <span>
                            <strong>
                                {pending_approvals} purchase approvals waiting
                            </strong>
                            <small>Agents cannot spend without your decision.</small>
                        </span>
                        <b>›</b>
                    </button>
                    <button onClick={onImport}>
                        <span className="row-icon">?</span>
                        <span>
                            <strong>
                                {len(
                                    dashboard.spending.uncategorized
                                )} charges need categories
                            </strong>
                            <small>
                                Review data quality before trusting the totals.
                            </small>
                        </span>
                        <b>›</b>
                    </button>
                    <button onClick={onBudget}>
                        <span className="row-icon">$</span>
                        <span>
                            <strong>
                                {money(
                                    dashboard.spending.net_income, dashboard.currency
                                )}{" "}net income
                            </strong>
                            <small>
                                Income minus spending in the latest imported month.
                            </small>
                        </span>
                        <b>›</b>
                    </button>
                </div>
            </div>
            {not dashboard.has_data
            and <div className="mobile-cta-card">
                <h2>See your real money picture</h2>
                <p>
                    Run the synthetic feed or import a statement. SpendOS never labels demo data as live.
                </p>
                <div className="button-row">
                    <button className="button button-primary" onClick={onFeed}>
                        Run live demo
                    </button>
                    <button className="button button-secondary" onClick={onImport}>
                        Import CSV
                    </button>
                </div>
            </div>}
        </section>;
}

def:pub SpendingScreen(
    analytics: SpendingAnalytics,
    budget: BudgetView,
    currency: str,
    onBudget: Callable[[MouseEvent], None],
) -> JsxElement {
    has range: str = "Month";
    def select_week(_e: MouseEvent) {
        range = "Week";
    }
    def select_month(_e: MouseEvent) {
        range = "Month";
    }
    def select_quarter(_e: MouseEvent) {
        range = "Quarter";
    }
    def select_year(_e: MouseEvent) {
        range = "Year";
    }
    return
        <section className="money-screen">
            <div className="range-tabs" aria-label="Spending range">
                <button
                    className={"active" if range == "Week" else ""}
                    onClick={select_week}
                >
                    Week
                </button>
                <button
                    className={"active" if range == "Month" else ""}
                    onClick={select_month}
                >
                    Month
                </button>
                <button
                    className={"active" if range == "Quarter" else ""}
                    onClick={select_quarter}
                >
                    Quarter
                </button>
                <button
                    className={"active" if range == "Year" else ""}
                    onClick={select_year}
                >
                    Year
                </button>
            </div>
            <div className="summary-card grouped-card">
                <div className="money-row">
                    <span className="row-icon">↑</span>
                    <span>Income</span>
                    <strong>{money(analytics.income, currency)}</strong>
                </div>
                <div className="money-row">
                    <span className="row-icon">↓</span>
                    <span>Total spend</span>
                    <strong>{money(analytics.total_spend, currency)}</strong>
                </div>
                <div className="money-row">
                    <span className="row-icon">=</span>
                    <span>Net income</span>
                    <strong
                        className={"positive"
                            if analytics.net_income >= 0.0
                            else "negative"}
                    >
                        {money(analytics.net_income, currency)}
                    </strong>
                </div>
                <button className="money-row row-button" onClick={onBudget}>
                    <span className="row-icon">◎</span>
                    <span>Safe to spend</span>
                    <strong>
                        {money(budget.safe_to_spend, currency)
                            if budget.configured
                            else "Begin ›"}
                    </strong>
                </button>
            </div>
            <div className="section-label">Breakdown</div>
            <div className="category-card">
                <div className="category-total">
                    <span>Total spend in {analytics.period or "latest month"}</span>
                    <strong>{money(analytics.total_spend, currency)}</strong>
                    <small>Every amount comes from the current SpendOS graph.</small>
                </div>
                <div className="category-list">
                    {for item in analytics.category_breakdown {
                        <div className="category-row" key={item.category}>
                            <span className="category-dot"/>
                            <span>
                                <strong>{item.category}</strong>
                                <small>
                                    {item.transaction_count} transactions · {str(
                                        round(item.percentage)
                                    )}%
                                </small>
                            </span>
                            <div className="category-bar">
                                <span
                                    className="category-fill"
                                    style={{"width": str(item.percentage) + "%"}}
                                />
                            </div>
                            <b>{money(item.amount, currency)}</b>
                        </div>
                    }}
                    {not analytics.category_breakdown
                    and <div className="empty-inline">
                        Import transactions to see category spending.
                    </div>}
                </div>
            </div>
            <div className="section-label">Frequent spend</div>
            <div className="grouped-card">
                {for merchant in analytics.frequent_merchants {
                    <div className="insight-row" key={merchant.merchant}>
                        <span className="count-badge">
                            {merchant.transaction_count}×
                        </span>
                        <span>
                            <strong>{merchant.merchant}</strong>
                            <small>
                                Average {money(merchant.average_amount, currency)}
                            </small>
                        </span>
                        <b>{money(merchant.total_amount, currency)}</b>
                    </div>
                }}
                {not analytics.frequent_merchants
                and <div className="empty-inline">
                    No frequently repeated merchants yet.
                </div>}
            </div>
            <div className="section-label">Largest purchases</div>
            <div className="grouped-card">
                {for transaction in analytics.largest_purchases {
                    <FeedTransactionRow
                        key={transaction.transaction_id}
                        transaction={transaction}
                        currency={currency}
                    />
                }}
            </div>
        </section>;
}

def:pub RecurringScreen(
    dashboard: Dashboard, onInvestigate: Callable[[str], None],
) -> JsxElement {
    has tab: str = "upcoming";
    def show_upcoming(_e: MouseEvent) {
        tab = "upcoming";
    }
    def show_all(_e: MouseEvent) {
        tab = "all";
    }
    visible: list[SubscriptionView] = (
        dashboard.spending.upcoming_recurring
            if tab == "upcoming"
            else dashboard.subscriptions
    );
    return
        <section className="money-screen">
            <div className="sub-tabs">
                <button
                    className={"active" if tab == "upcoming" else ""}
                    onClick={show_upcoming}
                >
                    Upcoming
                </button>
                <button className={"active" if tab == "all" else ""} onClick={show_all}>
                    All
                </button>
            </div>
            {tab == "upcoming"
            and <div className="calendar-card">
                <div>
                    <span>Next recurring obligations</span>
                    <strong>{len(visible)} detected</strong>
                </div>
                <div className="calendar-strip">
                    {for day in ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] {
                        <span key={day}>
                            {day[0:1]}
                            <b>•</b>
                        </span>
                    }}
                </div>
                <small>
                    Projected from transaction cadence. No bank calendar is connected.
                </small>
            </div>}
            <div className="section-heading recurring-heading">
                <div>
                    <div className="section-label">
                        {str(len(visible))} recurring charges
                    </div>
                    <h2>
                        {money(dashboard.annual_total, dashboard.currency)} per year
                    </h2>
                </div>
            </div>
            {not visible
            and <div className="empty-inline">
                No recurring charges in this view. Import more history to improve detection.
            </div>}
            <div className="subscription-list mobile-subscriptions">
                {for subscription in visible {
                    <SubscriptionRow
                        key={subscription.subscription_id}
                        subscription={subscription}
                        currency={dashboard.currency}
                        onInvestigate={onInvestigate}
                    />
                }}
            </div>
        </section>;
}

def:pub TransactionsScreen(
    transactions: list[TransactionView], currency: str
) -> JsxElement {
    has query: str = "",
        pending_only: bool = False;
    def edit_query(e: ChangeEvent) {
        query = e.target.value;
    }
    def toggle_pending(_e: MouseEvent) {
        pending_only = not pending_only;
    }
    filtered: list[TransactionView] = [
        transaction
        for transaction in transactions
        if (
            (
                not query
                or query.lower() in transaction.merchant.lower()
                or query.lower() in transaction.description.lower()
            )
            and (not pending_only or transaction.pending)
        )
    ];
    total: float = sum(
        [
            0.0 - transaction.amount
            for transaction in filtered
            if transaction.amount < 0.0
        ]
    );
    return
        <section className="money-screen">
            <div className="transaction-search">
                <span>⌕</span>
                <input
                    aria-label="Search transactions"
                    value={query}
                    onChange={edit_query}
                    placeholder="Search my transactions"
                />
                <button
                    className={"active" if pending_only else ""}
                    onClick={toggle_pending}
                    aria-pressed={str(pending_only)}
                >
                    Pending
                </button>
            </div>
            <div className="transaction-period">
                <strong>Latest imported activity</strong>
                <span>{money(total, currency)} total spend</span>
            </div>
            <div className="transaction-page-list">
                {for transaction in filtered {
                    <FeedTransactionRow
                        key={transaction.transaction_id}
                        transaction={transaction}
                        currency={currency}
                    />
                }}
                {not filtered
                and <div className="empty-inline">
                    No transactions match this search.
                </div>}
            </div>
        </section>;
}

def:pub AgentCenter(
    dashboard: Dashboard,
    onLive: Callable[[], None],
    onShopping: Callable[[MouseEvent], None],
    onPurchase: Callable[[MouseEvent], None],
    onBudget: Callable[[MouseEvent], None],
    onImport: Callable[[MouseEvent], None],
    onFeed: Callable[[], None],
    onFindings: Callable[[MouseEvent], None],
) -> JsxElement {
    return
        <section className="money-screen">
            <div className="agent-hero">
                <span className="agent-orb">A</span>
                <div>
                    <div className="step-label">SpendOS ↔ Hermes</div>
                    <h2>Your financial control plane</h2>
                    <p>
                        Hermes researches and proposes. SpendOS verifies the money. You remain in control.
                    </p>
                </div>
                <StatusPill label="Connected" tone="safe"/>
            </div>
            <div className="agent-metrics">
                <Metric
                    label="Missions"
                    value={str(len(dashboard.shopping_missions))}
                    detail="research delegated"
                />
                <Metric
                    label="Proposals"
                    value={str(len(dashboard.proposals))}
                    detail="policy evaluated"
                />
                <Metric
                    label="Findings"
                    value={str(len(dashboard.cases))}
                    detail="evidence backed"
                />
            </div>
            <div className="tool-grid">
                <button onClick={onLive}>
                    <span>●</span>
                    <strong>Live Agent</strong>
                    <small>Watch Hermes work</small>
                </button>
                <button onClick={onShopping}>
                    <span>⌕</span>
                    <strong>Shopping Agent</strong>
                    <small>Commission research</small>
                </button>
                <button onClick={onPurchase}>
                    <span>✓</span>
                    <strong>Purchase Guard</strong>
                    <small>Review proposals</small>
                </button>
                <button onClick={onBudget}>
                    <span>$</span>
                    <strong>Budget Guard</strong>
                    <small>Set safe limits</small>
                </button>
                <button onClick={onFindings}>
                    <span>!</span>
                    <strong>Guardian Findings</strong>
                    <small>Review evidence</small>
                </button>
                <button onClick={onFeed}>
                    <span>↻</span>
                    <strong>Run Demo</strong>
                    <small>Stream safe data</small>
                </button>
                <button onClick={onImport}>
                    <span>＋</span>
                    <strong>Import Data</strong>
                    <small>Add statement CSV</small>
                </button>
            </div>
            <div className="agent-boundary">
                <strong>Financial safety boundary</strong>
                <p>
                    Hermes has no tool to approve, checkout, transfer, cancel, or access bank credentials.
                </p>
            </div>
        </section>;
}

def:pub LiveAgentActivity(events: list[AgentActivityEvent]) -> JsxElement {
    return
        <section className="live-agent-screen">
            <div className="live-agent-hero">
                <div>
                    <div className="step-label">Discord → Hermes → SpendOS</div>
                    <h2>Hermes is working</h2>
                    <p>
                        Every step below comes from the real SpendOS MCP bridge. Research and policy checks are visible; checkout remains disabled.
                    </p>
                </div>
                <div className="live-signal">
                    <span/>
                    Listening
                </div>
            </div>
            <div className="live-agent-grid">
                <section className="activity-timeline">
                    <div className="section-heading">
                        <div>
                            <div className="step-label">Live execution trace</div>
                            <h2>What the agent is doing</h2>
                        </div>
                        <StatusPill
                            label={str(len(events)) + " events"}
                            tone="safe"
                        />
                    </div>
                    {not events
                    and <div className="activity-waiting">
                        <span className="activity-pulse"/>
                        <div>
                            <strong>Waiting for Hermes</strong>
                            <p>
                                Send a shopping request from Discord or ask Hermes to process a SpendOS mission.
                            </p>
                        </div>
                    </div>}
                    <div className="activity-list">
                        {for event in events {
                            <article
                                className={"activity-event activity-" + event.status}
                                key={str(event.id)}
                            >
                                <div className="activity-rail">
                                    <span/>
                                </div>
                                <div>
                                    <div className="activity-meta">
                                        <span>{event.phase}</span>
                                        <time>{event.time[11:19]}</time>
                                    </div>
                                    <h3>{event.title}</h3>
                                    <p>{event.detail}</p>
                                    <small>{event.tool}</small>
                                </div>
                            </article>
                        }}
                    </div>
                </section>
                <aside className="live-agent-boundary">
                    <div className="step-label">Authority boundary</div>
                    <h3>Visible and safe by design</h3>
                    <ul>
                        <li><strong>Hermes</strong> researches stores and products.</li>
                        <li><strong>SpendOS</strong> computes affordability and policy.</li>
                        <li><strong>You</strong> approve anything that needs judgment.</li>
                    </ul>
                    <div className="simulation-stamp">SIMULATION ONLY</div>
                    <p>
                        Walmart, Target, and Amazon results must come from verified provider tools. Local catalog results are labeled simulated.
                    </p>
                </aside>
            </div>
        </section>;
}

def:pub ShoppingAgent(
    missions: list[ShoppingMissionView],
    currency: str,
    busy: bool,
    onCreate: Callable[[str, float, str], None],
) -> JsxElement {
    has requestText: str = "",
        budgetText: str = "",
        preferencesText: str = "",
        formError: str = "";

    def edit_request(e: ChangeEvent) {
        requestText = e.target.value;
        formError = "";
    }
    def edit_budget(e: ChangeEvent) {
        budgetText = e.target.value;
        formError = "";
    }
    def edit_preferences(e: ChangeEvent) {
        preferencesText = e.target.value;
        formError = "";
    }
    def submit(e: FormEvent) {
        e.preventDefault();
        try {
            maximum = float(budgetText);
            if not requestText.strip() {
                formError = "Tell Hermes what you want it to find.";
            } elif maximum <= 0.0 {
                formError = "Set a maximum budget greater than zero.";
            } else {
                onCreate(requestText.strip(), maximum, preferencesText.strip());
            }
        } except Exception {
            formError = "Enter a valid maximum budget.";
        }
    }

    return
        <div className="shopping-layout">
            <form className="shopping-form" onSubmit={submit}>
                <div className="step-label">SpendOS → Hermes</div>
                <h2>Commission a shopping mission</h2>
                <p>
                    SpendOS defines the financial boundary. Hermes researches the market and returns evidence-backed options for review.
                </p>
                <label>
                    <span>What should Hermes find?</span>
                    <input
                        value={requestText}
                        onChange={edit_request}
                        placeholder="A quiet mechanical keyboard for a Mac"
                    />
                </label>
                <label>
                    <span>Maximum total budget</span>
                    <input
                        type="number"
                        min="0.01"
                        step="0.01"
                        value={budgetText}
                        onChange={edit_budget}
                        placeholder="150"
                    />
                </label>
                <label>
                    <span>Preferences and constraints</span>
                    <textarea
                        value={preferencesText}
                        onChange={edit_preferences}
                        placeholder="Mac compatible, quiet switches, no subscription"
                    />
                </label>
                {formError
                and <div className="notice notice-error" role="alert">{formError}</div>}
                <button className="button button-primary" disabled={busy} type="submit">
                    Send mission to Hermes
                </button>
                <small>
                    Research only. This does not authorize checkout or payment.
                </small>
            </form>
            <section className="mission-inbox" aria-labelledby="mission-inbox-title">
                <div className="section-heading">
                    <div>
                        <div className="step-label">Hermes → SpendOS</div>
                        <h2 id="mission-inbox-title">Shopping results</h2>
                        <p>
                            SpendOS independently checks returned prices and recurring costs.
                        </p>
                    </div>
                    <StatusPill label={str(len(missions)) + " missions"}/>
                </div>
                {not missions
                and <div className="empty-inline">
                    No missions yet. Create one and ask Hermes to process dispatched missions.
                </div>}
                <div className="mission-list">
                    {for mission in missions {
                        <article className="mission-card" key={mission.mission_id}>
                            <div className="mission-top">
                                <div>
                                    <div className="eyebrow">
                                        {mission.assigned_agent or "Waiting for Hermes"}
                                    </div>
                                    <h3>{mission.request}</h3>
                                    <p>
                                        {mission.preferences
                                        or "No additional preferences."}
                                    </p>
                                </div>
                                <StatusPill
                                    label={mission.status}
                                    tone={"safe"
                                        if mission.status == "READY_FOR_REVIEW"
                                        else "warn"}
                                />
                            </div>
                            <div className="mission-budget">
                                Maximum total:{" "}
                                <strong>
                                    {money(mission.maximum_budget, currency)}
                                </strong>
                            </div>
                            {not mission.candidates
                            and <div className="empty-inline">
                                Hermes has not returned candidates yet.
                            </div>}
                            <div className="candidate-list">
                                {for candidate in mission.candidates {
                                    <div
                                        className={"candidate candidate-safe"
                                            if candidate.within_budget
                                            else "candidate candidate-warning"}
                                        key={candidate.candidate_id}
                                    >
                                        <div>
                                            <strong>{candidate.product}</strong>
                                            <span>{candidate.merchant}</span>
                                        </div>
                                        <div>
                                            <strong>
                                                {money(
                                                    candidate.price + candidate.shipping,
                                                    currency
                                                )}
                                            </strong>
                                            <span>
                                                {money(
                                                    candidate.shipping, currency
                                                )} shipping
                                            </span>
                                        </div>
                                        <StatusPill
                                            label={"Within policy"
                                                if candidate.within_budget
                                                else "Needs review"}
                                            tone={"safe"
                                                if candidate.within_budget
                                                else "warn"}
                                        />
                                        <p>{candidate.warning or candidate.evidence}</p>
                                    </div>
                                }}
                            </div>
                            <div className="disclosure">
                                Research results only. No purchase occurred.
                            </div>
                        </article>
                    }}
                </div>
            </section>
        </div>;
}


def:pub app -> JsxElement {
    has dashboard: Dashboard | None = None,
        csvText: str = "",
        preview: ImportPreview | None = None,
        importResult: ImportResult | None = None,
        busy: bool = False,
        message: str = "",
        error: str = "",
        mode: str = "overview",
        revision: int = 0,
        feedHeader: str = "",
        feedRows: list[str] = [],
        feedCursor: int = 0,
        feedRunning: bool = False,
        feedEvents: list[str] = [],
        agentEvents: list[AgentActivityEvent] = [],
        agentActivityCursor: int = 0,
        activityPolling: bool = True;

    async def refresh {
        next_revision = revision + 1;
        revision = next_revision;
        dashboard = await get_dashboard(next_revision);
    }

    async can with entry {
        try {
            await refresh();
        } except Exception as e {
            error = "SpendOS could not read its graph: " + str(e);
        }
    }

    async def poll_agent_activity {
        if not activityPolling {
            return;
        }
        try {
            response = await fetch(
                "http://localhost:8765/events?after=" + str(agentActivityCursor)
            );
            if response.ok {
                payload: any = await response.json();
                incoming: list[AgentActivityEvent] = [];
                next_cursor: int = agentActivityCursor;
                raw_events: list[any] = payload["events"];
                for item in raw_events {
                    event = AgentActivityEvent(
                        id=int(item["id"]),
                        time=str(item["time"]),
                        tool=str(item["tool"]),
                        phase=str(item["phase"]),
                        title=str(item["title"]),
                        detail=str(item["detail"]),
                        status=str(item["status"])
                    );
                    incoming.append(event);
                    if event.id > next_cursor {
                        next_cursor = event.id;
                    }
                }
                if incoming {
                    agentEvents = (incoming + agentEvents)[0:80];
                    agentActivityCursor = next_cursor;
                    await refresh();
                }
            }
        } except Exception {
            # The bridge may be starting; the next poll retries automatically.
            activityPolling = True;
        }
        setTimeout(lambda { poll_agent_activity(); }, 800);
    }

    can with activityPolling entry {
        if activityPolling {
            setTimeout(lambda { poll_agent_activity(); }, 250);
        }
    }

    async def run_feed_step {
        if not feedRunning or feedCursor >= len(feedRows) {
            return;
        }
        batch_size: int = 5;
        next_cursor: int = feedCursor + batch_size;
        if next_cursor > len(feedRows) {
            next_cursor = len(feedRows);
        }
        batch_rows: list[str] = feedRows[feedCursor:next_cursor];
        batch_csv: str = feedHeader + "\n" + "\n".join(batch_rows);
        try {
            imported = root spawn ImportStatement(csv_text=batch_csv, currency="USD");
            root spawn AnalyzePortfolio(updated_count=0);
            await refresh();
            imported_count: int = (
                imported.reports[0].imported_count if imported.reports else 0
            );
            event: str = (
                f"Analyzed {imported_count} new transactions · " + f"{next_cursor} of {len(
                    feedRows
                )} processed"
            );
            feedEvents = [event] + feedEvents[0:7];
            feedCursor = next_cursor;
            if next_cursor >= len(feedRows) {
                feedRunning = False;
                message = "Synthetic bank feed complete. SpendOS stayed on top of every arrival.";
            }
        } except Exception as e {
            feedRunning = False;
            error = "Live feed stopped: " + str(e);
        }
    }

    can with [feedCursor, feedRunning] entry {
        if feedRunning and feedCursor < len(feedRows) {
            setTimeout(lambda { run_feed_step(); }, 700);
        }
    }

    async def start_feed {
        busy = True;
        error = "";
        try {
            await reset_demo_data();
            feed_text: str = await get_synthetic_feed();
            lines: list[str] = [
                line
                for line in feed_text.strip().split("\n")
                if line.strip()
            ];
            if len(lines) < 2 {
                raise ValueError("Synthetic feed has no transactions.");
            }
            feedHeader = lines[0];
            feedRows = lines[1:];
            feedCursor = 0;
            feedEvents = [
                "Connected synthetic checking ••4821 and rewards card ••1944",
                "Deterministic analysis is active; no model key is required",

            ];
            preview = None;
            importResult = None;
            csvText = feed_text;
            await refresh();
            mode = "feed";
            feedRunning = True;
            message = "Synthetic connection established. Transactions are arriving now.";
        } except Exception as e {
            feedRunning = False;
            error = "Could not start the synthetic feed: " + str(e);
        }
        busy = False;
    }

    def toggle_feed {
        feedRunning = not feedRunning;
        message = "Synthetic feed resumed."
            if feedRunning
            else "Synthetic feed paused.";
    }

    def edit_csv(e: ChangeEvent) {
        csvText = e.target.value;
        preview = None;
        importResult = None;
        error = "";
    }

    async def choose_file(e: ChangeEvent) {
        if e.target.files {
            csvText = str(await e.target.files[0].text());
            preview = None;
            importResult = None;
            error = "";
        }
    }

    def load_sample(e: MouseEvent) {
        csvText = SAMPLE_CSV;
        preview = None;
        importResult = None;
        error = "";
    }

    async def load_detailed_sample {
        busy = True;
        error = "";
        try {
            csvText = await get_synthetic_feed();
            preview = None;
            importResult = None;
            mode = "import";
            message = "Detailed synthetic bank CSV loaded for manual preview.";
        } except Exception as e {
            error = "Could not load the detailed sample: " + str(e);
        }
        busy = False;
    }

    async def run_preview {
        busy = True;
        error = "";
        try {
            result = await preview_statement(csvText, "USD");
            preview = result;
            if result.transactions {
                message = f"{len(result.transactions)} valid rows are ready to import.";
            } else {
                message = "No valid transactions were found.";
            }
        } except Exception as e {
            error = "Preview failed: " + str(e);
        }
        busy = False;
    }

    async def commit_import {
        busy = True;
        error = "";
        try {
            imported = root spawn ImportStatement(csv_text=csvText, currency="USD");
            if imported.reports {
                importResult = imported.reports[0];
            }
            analyzed = root spawn AnalyzePortfolio(updated_count=0);
            await refresh();
            mode = "overview";
            message = "Statement imported and recurring charges analyzed.";
        } except Exception as e {
            error = "Import failed: " + str(e);
        }
        busy = False;
    }

    async def investigate(subscriptionId: str) {
        busy = True;
        error = "";
        try {
            result = root spawn InvestigateSubscription(subscription_id=subscriptionId);
            await refresh();
            mode = "findings";
            message = "Guardian investigation completed from graph evidence.";
        } except Exception as e {
            error = "Investigation failed: " + str(e);
        }
        busy = False;
    }

    async def decide(caseId: str, choice: str) {
        busy = True;
        error = "";
        try {
            result = root spawn DecideCase(case_id=caseId, choice=choice);
            await refresh();
            mode = "findings";
            message = "Your decision is now part of SpendOS memory.";
        } except Exception as e {
            error = "Decision failed: " + str(e);
        }
        busy = False;
    }

    async def simulate(actionId: str) {
        busy = True;
        error = "";
        try {
            result = root spawn SimulateCancellation(action_id=actionId);
            await refresh();
            mode = "actions";
            message = "Cancellation simulation completed. No external action was performed.";
        } except Exception as e {
            error = "Simulation failed: " + str(e);
        }
        busy = False;
    }

    async def save_budget(income: float, fixed: float, reserve: float) {
        busy = True;
        error = "";
        try {
            _saved = await save_budget_plan(income, fixed, reserve);
            await refresh();
            mode = "budget";
            message = "Budget guardrails confirmed from your inputs.";
        } except Exception as e {
            error = "Budget update failed: " + str(e);
        }
        busy = False;
    }

    async def create_purchase_proposal(
        agent_id: str, merchant: str, purpose: str, amount: float, cadence: str,
    ) {
        busy = True;
        error = "";
        try {
            _proposal = await propose_purchase(
                agent_id, merchant, purpose, amount, cadence
            );
            await refresh();
            mode = "purchase";
            message = "Purchase preflight completed. No purchase occurred.";
        } except Exception as e {
            error = "Purchase preflight failed: " + str(e);
        }
        busy = False;
    }

    async def create_mission(request: str, maximum: float, preferences: str) {
        busy = True;
        error = "";
        try {
            _mission = await create_shopping_mission(request, maximum, preferences);
            await refresh();
            mode = "shopping";
            message = "Shopping mission dispatched to Hermes. No purchase occurred.";
        } except Exception as e {
            error = "Shopping mission failed: " + str(e);
        }
        busy = False;
    }

    async def decide_purchase(proposalId: str, choice: str) {
        busy = True;
        error = "";
        try {
            _result = await decide_purchase_proposal(proposalId, choice);
            await refresh();
            mode = "purchase";
            message = "Purchase proposal updated. No purchase occurred.";
        } except Exception as e {
            error = "Purchase decision failed: " + str(e);
        }
        busy = False;
    }

    async def simulate_purchase_proposal(proposalId: str) {
        busy = True;
        error = "";
        try {
            _result = await simulate_purchase(proposalId);
            await refresh();
            mode = "purchase";
            message = "Purchase simulation completed. No purchase occurred.";
        } except Exception as e {
            error = "Purchase simulation failed: " + str(e);
        }
        busy = False;
    }

    async def reset_all {
        busy = True;
        error = "";
        try {
            await reset_demo_data();
            preview = None;
            importResult = None;
            csvText = "";
            feedHeader = "";
            feedRows = [];
            feedCursor = 0;
            feedRunning = False;
            feedEvents = [];
            await refresh();
            mode = "overview";
            message = "Local SpendOS graph reset.";
        } except Exception as e {
            error = "Reset failed: " + str(e);
        }
        busy = False;
    }

    def show_overview {
        mode = "overview";
    }
    def show_import {
        mode = "import";
    }
    def show_feed {
        mode = "feed";
    }
    def show_findings {
        mode = "findings";
    }
    def show_actions {
        mode = "actions";
    }
    def show_budget {
        mode = "budget";
    }
    def show_purchase {
        mode = "purchase";
    }
    def show_shopping {
        mode = "shopping";
    }
    def show_recurring {
        mode = "recurring";
    }
    def show_spending {
        mode = "spending";
    }
    def show_transactions {
        mode = "transactions";
    }
    def show_agent {
        mode = "agent";
    }
    def show_live {
        mode = "live_agent";
    }

    if dashboard is None {
        return
            <div className="loading-screen" role="status">
                <div className="brand-mark">S</div>
                <strong>SpendOS is reading your financial graph…</strong>
            </div>;
    }

    return
        <div className="app-shell">
            <aside className="sidebar">
                <div className="brand-lockup">
                    <div className="brand-mark">S</div>
                    <div>
                        <strong>SpendOS</strong>
                        <span>Subscription Guardian</span>
                    </div>
                </div>
                <nav aria-label="SpendOS primary sections">
                    <button
                        className={"nav-item active"
                            if mode == "live_agent"
                            else "nav-item"}
                        onClick={show_live}
                    >
                        <span className="nav-icon live-nav-icon">●</span>
                        <span className="nav-label">Live</span>
                    </button>
                    <button
                        className={"nav-item active"
                            if mode == "overview"
                            else "nav-item"}
                        onClick={show_overview}
                    >
                        <span className="nav-icon">⌂</span>
                        <span className="nav-label">Home</span>
                    </button>
                    <button
                        className={"nav-item active"
                            if mode == "recurring"
                            else "nav-item"}
                        onClick={show_recurring}
                    >
                        <span className="nav-icon">↻</span>
                        <span className="nav-label">Recurring</span>
                    </button>
                    <button
                        className={"nav-item active"
                            if mode == "spending"
                            else "nav-item"}
                        onClick={show_spending}
                    >
                        <span className="nav-icon">$</span>
                        <span className="nav-label">Spending</span>
                    </button>
                    <button
                        className={"nav-item active"
                            if mode == "transactions"
                            else "nav-item"}
                        onClick={show_transactions}
                    >
                        <span className="nav-icon">⌕</span>
                        <span className="nav-label">Transactions</span>
                    </button>
                    <button
                        className={"nav-item active"
                            if mode in [
                                "agent",
                                "shopping",
                                "purchase",
                                "budget",
                                "feed",
                                "import",
                                "findings",
                                                            "actions"
                            ]
                            else "nav-item"}
                        onClick={show_agent}
                    >
                        <span className="nav-icon agent-nav-icon">A</span>
                        <span className="nav-label">Agent</span>
                    </button>
                </nav>
                <div className="guardian-status">
                    <span className="status-dot"/>
                    <div>
                        <strong>Guardian active</strong>
                        <small>
                            {"Analyzing feed now"
                                if feedRunning
                                else "Watching imported data"}
                        </small>
                    </div>
                </div>
                <button className="reset-link" onClick={reset_all}>
                    Reset local data
                </button>
            </aside>
            <main className="main">
                <header className="topbar">
                    <div>
                        <div className="eyebrow">
                            SpendOS · Financial safety, continuously
                        </div>
                        <h1>
                            {"Today"
                                if mode == "overview"
                                else (
                                    "Recurring"
                                        if mode == "recurring"
                                        else (
                                            "Spending"
                                                if mode == "spending"
                                                else (
                                                    "Transactions"
                                                        if mode == "transactions"
                                                        else (
                                                            "Agent Center"
                                                                if mode == "agent"
                                                                else (
                                                                    "Live agent activity"
                                                                        if mode == "live_agent"
                                                                        else (
                                                                            "Live financial activity"
                                                                                if mode == "feed"
                                                                                else (
                                                                                    "Import a statement"
                                                                                        if mode == "import"
                                                                                        else (
                                                                                            "Guardian findings"
                                                                                                if mode == "findings"
                                                                                                else (
                                                                                                    "Controlled actions"
                                                                                                        if mode == "actions"
                                                                                                        else (
                                                                                                            "Agent Purchase Guard"
                                                                                                                if mode == "purchase"
                                                                                                                else (
                                                                                                                    "Hermes Shopping Agent"
                                                                                                                        if mode == "shopping"
                                                                                                                        else "Budget Guard"
                                                                                                                )
                                                                                                        )
                                                                                                )
                                                                                        )
                                                                                )
                                                                        )
                                                                )
                                                        )
                                                )
                                        )
                                )}
                        </h1>
                    </div>
                    <StatusPill
                        label={"Live analysis"
                            if feedRunning
                            else ("Working" if busy else "Up to date")}
                        tone={"safe" if feedRunning else ("warn" if busy else "safe")}
                    />
                </header>
                {error
                and <div className="notice notice-error" role="alert">{error}</div>}
                {message
                and not error
                and <div className="notice" role="status">{message}</div>}
                {mode == "overview"
                and <HomeScreen
                    dashboard={dashboard}
                    onFeed={start_feed}
                    onBudget={show_budget}
                    onImport={show_import}
                    onAgent={show_agent}
                />}
                {mode == "recurring"
                and <RecurringScreen
                    dashboard={dashboard}
                    onInvestigate={investigate}
                />}
                {mode == "spending"
                and <SpendingScreen
                    analytics={dashboard.spending}
                    budget={dashboard.budget}
                    currency={dashboard.currency}
                    onBudget={show_budget}
                />}
                {mode == "transactions"
                and <TransactionsScreen
                    transactions={dashboard.recent_transactions}
                    currency={dashboard.currency}
                />}
                {mode == "agent"
                and <AgentCenter
                    dashboard={dashboard}
                    onLive={show_live}
                    onShopping={show_shopping}
                    onPurchase={show_purchase}
                    onBudget={show_budget}
                    onImport={show_import}
                    onFeed={start_feed}
                    onFindings={show_findings}
                />}
                {mode == "live_agent"
                and <LiveAgentActivity events={agentEvents}/>}
                {mode == "legacy_overview"
                and <section>
                    {not dashboard.has_data
                    and <div className="empty-hero">
                        <div className="empty-icon">◎</div>
                        <h2>Let SpendOS find what keeps charging you.</h2>
                        <p>
                            Start a detailed synthetic bank feed or import your own statement. SpendOS will detect recurring charges as they arrive, explain what deserves attention, and remember every decision.
                        </p>
                        <div className="button-row">
                            <button
                                className="button button-primary"
                                onClick={start_feed}
                            >
                                Watch the live demo
                            </button>
                            <button
                                className="button button-secondary"
                                onClick={show_import}
                            >
                                Import your statement
                            </button>
                        </div>
                        <span>CSV stays in your local SpendOS graph.</span>
                    </div>}{dashboard.has_data
                    and <div>
                        <div className="metrics">
                            <Metric
                                label="Monthly recurring"
                                value={money(
                                    dashboard.monthly_total, dashboard.currency
                                )}
                                detail="deterministic total"
                            />
                            <Metric
                                label="Annual commitment"
                                value={money(
                                    dashboard.annual_total, dashboard.currency
                                )}
                                detail="at current prices"
                            />
                            <Metric
                                label="Subscriptions found"
                                value={str(dashboard.subscription_count)}
                                detail={str(dashboard.transaction_count) + " transactions analyzed"}
                            />
                        </div>
                        <div className="section-heading">
                            <div>
                                <h2>Recurring charges</h2>
                                <p>Sorted by monthly impact.</p>
                            </div>
                            <button
                                className="button button-secondary"
                                onClick={show_import}
                            >
                                Add statement
                            </button>
                        </div>
                        <div className="subscription-list">
                            {for subscription in dashboard.subscriptions {
                                <SubscriptionRow
                                    key={subscription.subscription_id}
                                    subscription={subscription}
                                    currency={dashboard.currency}
                                    onInvestigate={investigate}
                                />
                            }}
                        </div>
                    </div>}
                </section>}
                {mode == "feed"
                and <LiveFeedPanel
                    dashboard={dashboard}
                    progress={feedCursor}
                    total={len(feedRows)}
                    running={feedRunning}
                    events={feedEvents}
                    onStart={start_feed}
                    onToggle={toggle_feed}
                />}
                {mode == "import"
                and <section className="import-layout">
                    <div className="import-card">
                        <div className="step-label">Step 1 of 2</div>
                        <h2>Choose a bank-statement CSV</h2>
                        <p>
                            Required columns are{" "}
                            <code>date,description,amount</code>
                            . Detailed merchant, category, account, channel, location, and pending fields are accepted when available. Charges should be negative.
                        </p>
                        <label className="file-picker">
                            <input
                                type="file"
                                accept=".csv,text/csv"
                                onChange={choose_file}
                            />
                            <span>Select CSV</span>
                            <small>or paste its contents below</small>
                        </label>
                        <textarea
                            value={csvText}
                            onChange={edit_csv}
                            placeholder={"date,description,amount\n2025-01-05,Netflix,-22.99"}
                            aria-label="CSV statement contents"
                        />
                        <div className="button-row">
                            <button
                                className="button button-quiet"
                                onClick={load_sample}
                            >
                                Use safe sample
                            </button>
                            <button
                                className="button button-quiet"
                                onClick={load_detailed_sample}
                            >
                                Load detailed bank CSV
                            </button>
                            <button
                                className="button button-primary"
                                disabled={busy or not csvText}
                                onClick={run_preview}
                            >
                                Preview import
                            </button>
                        </div>
                    </div>
                    <div className="preview-card">
                        <div className="step-label">Step 2 of 2</div>
                        <h2>Verify before saving</h2>
                        {not preview
                        and <div className="preview-empty">
                            Your validated totals and rejected rows will appear here.
                        </div>}
                        {preview
                        and <ImportPreviewPanel
                            preview={preview}
                            busy={busy}
                            onCommit={commit_import}
                        />}
                    </div>
                </section>}
                {mode == "budget"
                and <section>
                    <BudgetGuard
                        budget={dashboard.budget}
                        currency={dashboard.currency}
                        busy={busy}
                        onSave={save_budget}
                    />
                </section>}
                {mode == "purchase"
                and <PurchaseGuard
                    proposals={dashboard.proposals}
                    currency={dashboard.currency}
                    budget={dashboard.budget}
                    busy={busy}
                    onPropose={create_purchase_proposal}
                    onDecision={decide_purchase}
                    onSimulate={simulate_purchase_proposal}
                />}
                {mode == "shopping"
                and <ShoppingAgent
                    missions={dashboard.shopping_missions}
                    currency={dashboard.currency}
                    busy={busy}
                    onCreate={create_mission}
                />}
                {mode == "findings"
                and <section>
                    <div className="section-heading">
                        <div>
                            <h2>Evidence-backed recommendations</h2>
                            <p>
                                SpendOS never treats a model response as authorization.
                            </p>
                        </div>
                    </div>
                    {not dashboard.cases
                    and <div className="empty-inline">
                        Investigate a subscription from Overview to create a finding.
                    </div>}
                    <div className="case-grid">
                        {for caseItem in dashboard.cases {
                            <CaseCard
                                key={caseItem.case_id}
                                caseItem={caseItem}
                                currency={dashboard.currency}
                                onDecision={decide}
                            />
                        }}
                    </div>
                </section>}
                {mode == "actions"
                and <section>
                    <div className="section-heading">
                        <div>
                            <h2>Approved simulations</h2>
                            <p>
                                Every state change is explicit, reviewable, and local.
                            </p>
                        </div>
                    </div>
                    {not dashboard.actions
                    and <div className="empty-inline">
                        No cancellation has been approved. SpendOS cannot act without you.
                    </div>}
                    <div className="case-grid">
                        {for action in dashboard.actions {
                            <ActionCard
                                key={action.action_id}
                                action={action}
                                currency={dashboard.currency}
                                onSimulate={simulate}
                            />
                        }}
                    </div>
                </section>}
            </main>
        </div>;
}
