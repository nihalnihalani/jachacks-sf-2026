"""SpendOS subscription guardian domain model and deterministic helpers."""

import csv;
import hashlib;
import io;
import re;
import from datetime { datetime, timedelta }


obj RejectedRow {
    has row_number: int,
        raw: str,
        reason: str;
}

obj ParsedTransaction {
    has fingerprint: str,
        date: str,
        description: str,
        merchant_name: str,
        amount: float,
        currency: str,
        category: str = "Uncategorized",
        subcategory: str = "",
        account_name: str = "Checking",
        account_mask: str = "",
        transaction_type: str = "DEBIT",
        payment_channel: str = "other",
        city: str = "",
        region: str = "",
        country: str = "US",
        pending: bool = False;
}

obj ImportPreview {
    has statement_fingerprint: str,
        transactions: list[ParsedTransaction] = [],
        rejected: list[RejectedRow] = [],
        debit_total: float = 0.0,
        credit_total: float = 0.0,
        currency: str = "USD";
}

obj ImportResult {
    has statement_id: str = "",
        imported_count: int = 0,
        duplicate_count: int = 0,
        rejected: list[RejectedRow] = [],
        debit_total: float = 0.0,
        currency: str = "USD";
}

obj PricePoint {
    has date: str,
        amount: float;
}

obj TransactionView {
    has transaction_id: str,
        date: str,
        description: str,
        merchant: str,
        amount: float,
        currency: str,
        category: str,
        subcategory: str,
        account_name: str,
        account_mask: str,
        transaction_type: str,
        payment_channel: str,
        location: str,
        pending: bool;
}

obj SubscriptionView {
    has subscription_id: str,
        merchant: str,
        cadence: str,
        monthly_cost: float,
        last_amount: float,
        next_expected: str,
        confidence: float,
        price_change: float,
        status: str,
        protected: bool,
        transaction_count: int;
}

obj CaseView {
    has case_id: str,
        subscription_id: str,
        merchant: str,
        recommendation: str,
        reason: str,
        annual_savings: float,
        confidence: float,
        evidence_ids: list[str] = [],
        source: str = "deterministic",
        state: str = "OPEN";
}

obj ActionView {
    has action_id: str,
        case_id: str,
        merchant: str,
        state: str,
        annual_savings: float,
        approved_at: str = "",
        simulated_at: str = "",
        disclosure: str = "No external action was performed.";
}

obj BudgetView {
    has configured: bool = False,
        monthly_income: float = 0.0,
        fixed_obligations: float = 0.0,
        recurring_obligations: float = 0.0,
        safety_reserve: float = 0.0,
        safe_to_spend: float = 0.0,
        status: str = "NOT_CONFIGURED",
        warning: str = "",
        confirmed_at: str = "";
}

obj PurchaseProposalView {
    has proposal_id: str,
        agent_id: str,
        merchant: str,
        purpose: str,
        amount: float,
        cadence: str,
        monthly_cost: float,
        projected_safe_to_spend: float,
        outcome: str,
        state: str,
        reason: str,
        created_at: str,
        decided_at: str = "";
}

obj ShoppingCandidateView {
    has candidate_id: str,
        mission_id: str,
        merchant: str,
        product: str,
        price: float,
        shipping: float,
        recurring_cost: float,
        product_url: str,
        evidence: str,
        within_budget: bool,
        warning: str = "";
}

obj ShoppingCandidateInput {
    has merchant: str,
        product: str,
        price: float,
        shipping: float = 0.0,
        recurring_cost: float = 0.0,
        product_url: str = "",
        evidence: str = "";
}

obj ShoppingMissionView {
    has mission_id: str,
        request: str,
        maximum_budget: float,
        preferences: str,
        status: str,
        assigned_agent: str,
        created_at: str,
        updated_at: str,
        candidates: list[ShoppingCandidateView] = [];
}

obj CategorySpendView {
    has category: str,
        amount: float,
        percentage: float,
        transaction_count: int;
}

obj MerchantSpendView {
    has merchant: str,
        transaction_count: int,
        average_amount: float,
        total_amount: float;
}

obj SpendingAnalytics {
    has period: str = "",
        income: float = 0.0,
        total_spend: float = 0.0,
        net_income: float = 0.0,
        category_breakdown: list[CategorySpendView] = [],
        frequent_merchants: list[MerchantSpendView] = [],
        largest_purchases: list[TransactionView] = [],
        uncategorized: list[TransactionView] = [],
        upcoming_recurring: list[SubscriptionView] = [];
}

obj Dashboard {
    has has_data: bool = False,
        statement_count: int = 0,
        transaction_count: int = 0,
        subscription_count: int = 0,
        monthly_total: float = 0.0,
        annual_total: float = 0.0,
        currency: str = "USD",
        recent_transactions: list[TransactionView] = [],
        subscriptions: list[SubscriptionView] = [],
        cases: list[CaseView] = [],
        actions: list[ActionView] = [],
        proposals: list[PurchaseProposalView] = [],
        shopping_missions: list[ShoppingMissionView] = [],
        spending: SpendingAnalytics = SpendingAnalytics(),
        budget: BudgetView = BudgetView();
}

obj AgentAssessment {
    has recommendation: str,
        reason: str,
        confidence: float,
        evidence_ids: list[str] = [];
}

sem AgentAssessment.recommendation = "Exactly one of KEEP, REVIEW, DOWNGRADE, or CANCEL.";
sem AgentAssessment.reason = "A concise explanation grounded only in tool evidence. Never infer non-use.";
sem AgentAssessment.confidence = "Confidence from zero to one. Low confidence must be REVIEW.";
sem AgentAssessment.evidence_ids = "Evidence ids supporting every factual claim.";

node Statement {
    has statement_id: str,
        fingerprint: str,
        currency: str,
        imported_at: str,
        debit_total: float = 0.0,
        transaction_count: int = 0;
}

node Transaction {
    has transaction_id: str,
        fingerprint: str,
        date: str,
        description: str,
        amount: float,
        currency: str,
        category: str = "Uncategorized",
        subcategory: str = "",
        account_name: str = "Checking",
        account_mask: str = "",
        transaction_type: str = "DEBIT",
        payment_channel: str = "other",
        city: str = "",
        region: str = "",
        country: str = "US",
        pending: bool = False;
}

node Merchant {
    has merchant_id: str,
        normalized_name: str,
        display_name: str;
}

node Subscription {
    has subscription_id: str,
        merchant_id: str,
        merchant_name: str,
        cadence: str,
        monthly_cost: float,
        last_amount: float,
        next_expected: str,
        confidence: float,
        price_change: float = 0.0,
        status: str = "ACTIVE",
        protected: bool = False,
        transaction_count: int = 0,
        analyzed_at: str = "";
}

node Evidence {
    has evidence_id: str,
        kind: str,
        summary: str,
        amount: float = 0.0,
        occurred_at: str = "";
}

node SubscriptionCase {
    has case_id: str,
        subscription_id: str,
        merchant_name: str,
        recommendation: str,
        reason: str,
        annual_savings: float,
        confidence: float,
        evidence_ids: list[str] = [],
        source: str = "deterministic",
        state: str = "OPEN",
        created_at: str = "";
}

node Decision {
    has decision_id: str,
        case_id: str,
        choice: str,
        decided_at: str,
        note: str = "";
}

node Preference {
    has preference_id: str,
        merchant_id: str,
        rule: str,
        value: str,
        created_at: str;
}

node Precedent {
    has precedent_id: str,
        merchant_id: str,
        outcome: str,
        reason: str,
        created_at: str,
        hit_count: int = 0;
}

node SimulatedAction {
    has action_id: str,
        case_id: str,
        merchant_name: str,
        state: str = "PROPOSED",
        annual_savings: float = 0.0,
        approved_at: str = "",
        simulated_at: str = "";
}

node BudgetPlan {
    has plan_id: str,
        monthly_income: float,
        fixed_obligations: float,
        safety_reserve: float,
        confirmed_at: str,
        updated_at: str;
}

node AgentIdentity {
    has agent_id: str,
        display_name: str,
        created_at: str;
}

node PurchaseProposal {
    has proposal_id: str,
        agent_id: str,
        merchant: str,
        purpose: str,
        amount: float,
        cadence: str,
        monthly_cost: float,
        projected_safe_to_spend: float,
        outcome: str,
        state: str,
        reason: str,
        created_at: str,
        decided_at: str = "";
}

node ShoppingMission {
    has mission_id: str,
        request: str,
        maximum_budget: float,
        preferences: str,
        created_at: str,
        updated_at: str,
        status: str = "DISPATCHED",
        assigned_agent: str = "";
}

node ShoppingCandidate {
    has candidate_id: str,
        mission_id: str,
        merchant: str,
        product: str,
        price: float,
        shipping: float,
        recurring_cost: float,
        product_url: str,
        evidence: str,
        created_at: str;
}

edge Contains: Statement --> Transaction {}
edge PaidTo: Transaction --> Merchant {}
edge RecursAs: Transaction --> Subscription {
    has match_confidence: float = 0.0;
}

edge CaseFor: SubscriptionCase --> Subscription {}
edge SupportedBy: SubscriptionCase --> Evidence {}
edge DecidedBy: SubscriptionCase --> Decision {}
edge Establishes: Decision --> Precedent {}
edge AppliesTo: Preference --> Subscription {}
edge ActsOn: SimulatedAction --> SubscriptionCase {}
edge ProposedBy: PurchaseProposal --> AgentIdentity {}
edge CandidateFor: ShoppingCandidate --> ShoppingMission {}


def calculate_safe_to_spend(
    monthly_income: float,
    fixed_obligations: float,
    recurring_obligations: float,
    safety_reserve: float
) -> float {
    return round(
        monthly_income - fixed_obligations - recurring_obligations - safety_reserve, 2
    );
}

def normalize_purchase_monthly_cost(amount: float, cadence: str) -> float {
    normalized_cadence = cadence.upper().strip();
    if amount <= 0.0 {
        raise ValueError("Purchase amount must be greater than zero.");
    }
    if normalized_cadence == "MONTHLY" {
        return round(amount, 2);
    }
    if normalized_cadence == "QUARTERLY" {
        return round(amount / 3.0, 2);
    }
    if normalized_cadence == "ANNUAL" or normalized_cadence == "YEARLY" {
        return round(amount / 12.0, 2);
    }
    if normalized_cadence == "ONE_TIME" {
        return round(amount, 2);
    }
    raise ValueError(
        "Cadence must be MONTHLY, QUARTERLY, ANNUAL, YEARLY, or ONE_TIME."
    );
}


def now_iso -> str {
    return datetime.now().astimezone().isoformat(timespec="seconds");
}


def stable_id(prefix: str, value: str) -> str {
    digest = hashlib.sha256(value.encode("utf-8")).hexdigest()[0:16];
    return f"{prefix}_{digest}";
}


def normalize_merchant(description: str) -> str {
    value: str = description.upper().strip();
    value = re.sub(r"\b(POS|DEBIT|PURCHASE|PAYMENT|RECURRING|CARD|COM)\b", " ", value);
    value = re.sub(r"\b\d{2,}\b", " ", value);
    value = re.sub(r"[^A-Z0-9 ]", " ", value);
    value = re.sub(r"\s+", " ", value).strip();
    return value or description.upper().strip();
}


def parse_date(value: str) -> any {
    for fmt in ["%Y-%m-%d", "%m/%d/%Y", "%m/%d/%y"] {
        try {
            return datetime.strptime(value.strip(), fmt);
        } except ValueError {
            continue;
        }
    }
    raise ValueError("date must use YYYY-MM-DD or MM/DD/YYYY");
}


def parse_csv_row(row: any, currency: str) -> ParsedTransaction {
    date_obj = parse_date(str(row.get("date", "")));
    date_text: str = str(date_obj.strftime("%Y-%m-%d"));
    description: str = str(row.get("description", "")).strip();
    if not description {
        raise ValueError("description is required");
    }
    amount: float = float(str(row.get("amount", "")).replace("$", "").replace(",", ""));
    amount = round(amount, 2);
    merchant_raw: str = str(row.get("merchant", "")).strip();
    merchant: str = normalize_merchant(merchant_raw or description);
    category: str = str(row.get("category", "Uncategorized")).strip()
    or "Uncategorized";
    subcategory: str = str(row.get("subcategory", "")).strip();
    account_name: str = str(row.get("account_name", "Checking")).strip() or "Checking";
    account_mask: str = str(row.get("account_mask", "")).strip();
    transaction_type: str = str(
        row.get("transaction_type", "CREDIT" if amount > 0.0 else "DEBIT")
    ).strip().upper();
    payment_channel: str = str(row.get("payment_channel", "other")).strip().lower();
    city: str = str(row.get("city", "")).strip();
    region: str = str(row.get("region", "")).strip();
    country: str = str(row.get("country", "US")).strip().upper() or "US";
    pending_text: str = str(row.get("pending", "false")).strip().lower();
    pending: bool = pending_text in ["true", "1", "yes", "pending"];
    fingerprint: str = stable_id(
        "txn", f"{date_text}|{merchant}|{amount:.2f}|{currency}|{account_mask}"
    );
    return ParsedTransaction(
        fingerprint=fingerprint,
        date=date_text,
        description=description,
        merchant_name=merchant,
        amount=amount,
        currency=currency,
        category=category,
        subcategory=subcategory,
        account_name=account_name,
        account_mask=account_mask,
        transaction_type=transaction_type,
        payment_channel=payment_channel,
        city=city,
        region=region,
        country=country,
        pending=pending
    );
}


def parse_statement_csv(csv_text: str, currency: str = "USD") -> ImportPreview {
    body = csv_text.strip();
    if not body {
        return ImportPreview(
            statement_fingerprint=stable_id("stmt", ""),
            rejected=[RejectedRow(row_number=1, raw="", reason="The file is empty.")],
            currency=currency
        );
    }
    parsed: list[ParsedTransaction] = [];
    rejected: list[RejectedRow] = [];
    debit_total = 0.0;
    credit_total = 0.0;
    reader = csv.DictReader(io.StringIO(body));
    headers = [str(h).strip().lower() for h in (reader.fieldnames or [])];
    required_headers: list[str] = ["date", "description", "amount"];
    missing_headers: list[str] = [
        header
        for header in required_headers
        if header not in headers
    ];
    if missing_headers {
        return ImportPreview(
            statement_fingerprint=stable_id("stmt", body),
            rejected=[
                RejectedRow(
                    row_number=1,
                    raw=",".join(headers),
                    reason="Missing required columns: " + ",".join(missing_headers)
                )
            ],
            currency=currency
        );
    }
    row_number = 1;
    for row in reader {
        row_number += 1;
        raw = ",".join([str(row.get(k, "")) for k in headers]);
        try {
            transaction = parse_csv_row(row, currency);
            parsed.append(transaction);
            if transaction.amount < 0.0 {
                debit_total += 0.0 - transaction.amount;
            } else {
                credit_total += transaction.amount;
            }
        } except Exception as e {
            rejected.append(RejectedRow(row_number=row_number, raw=raw, reason=str(e)));
        }
    }
    statement_key = "|".join(sorted([t.fingerprint for t in parsed]));
    return ImportPreview(
        statement_fingerprint=stable_id("stmt", statement_key),
        transactions=parsed,
        rejected=rejected,
        debit_total=round(debit_total, 2),
        credit_total=round(credit_total, 2),
        currency=currency
    );
}


def days_between(earlier: str, later: str) -> int {
    return int(parse_date(later).toordinal()) - int(parse_date(earlier).toordinal());
}


def add_days(date_text: str, days: int) -> str {
    ordinal: int = int(parse_date(date_text).toordinal()) + days;
    return str(datetime.fromordinal(ordinal).strftime("%Y-%m-%d"));
}


def median(values: list[float]) -> float {
    if not values {
        return 0.0;
    }
    ordered = sorted(values);
    middle = len(ordered) // 2;
    if len(ordered) % 2 == 1 {
        return float(ordered[middle]);
    }
    return (ordered[middle - 1] + ordered[middle]) / 2.0;
}


def absolute(value: float) -> float {
    return 0.0 - value if value < 0.0 else value;
}


def detect_recurrence(points: list[PricePoint]) -> SubscriptionView | None {
    if len(points) < 2 {
        return None;
    }
    ordered: list[PricePoint] = sorted(points, key=lambda (p: PricePoint) { p.date; });
    intervals: list[float] = [];
    amounts: list[float] = [];
    for point in ordered {
        amounts.append(absolute(point.amount));
    }
    index = 1;
    while index < len(ordered) {
        intervals.append(
            float(days_between(ordered[index - 1].date, ordered[index].date))
        );
        index += 1;
    }
    typical_days = median(intervals);
    cadence = "";
    cadence_days = 0;
    monthly_factor = 1.0;
    if typical_days >= 25.0 and typical_days <= 35.0 {
        cadence = "MONTHLY";
        cadence_days = 30;
    } elif typical_days >= 80.0 and typical_days <= 100.0 {
        cadence = "QUARTERLY";
        cadence_days = 91;
        monthly_factor = 1.0 / 3.0;
    } elif typical_days >= 340.0 and typical_days <= 390.0 {
        cadence = "ANNUAL";
        cadence_days = 365;
        monthly_factor = 1.0 / 12.0;
    } else {
        return None;
    }
    typical_amount = median(amounts);
    if typical_amount <= 0.0 {
        return None;
    }
    max_delta: float = 0.0;
    for value in amounts {
        delta: float = absolute(value - typical_amount) / typical_amount;
        if delta > max_delta {
            max_delta = delta;
        }
    }
    if max_delta > 0.25 {
        return None;
    }
    interval_score: float = 1.0 - absolute(typical_days - float(cadence_days)) / float(
        cadence_days
    );
    if interval_score < 0.0 {
        interval_score = 0.0;
    }
    amount_score: float = 1.0 - max_delta;
    if amount_score < 0.0 {
        amount_score = 0.0;
    }
    history_bonus: float = 0.02 * float(len(points) if len(points) < 4 else 4);
    confidence: float = 0.55 + 0.25 * interval_score + 0.15 * amount_score + history_bonus;
    if confidence > 0.99 {
        confidence = 0.99;
    }
    latest: PricePoint = ordered[len(ordered) - 1];
    previous: PricePoint = ordered[len(ordered) - 2];
    price_change: float = round(absolute(latest.amount) - absolute(previous.amount), 2);
    return SubscriptionView(
        subscription_id="",
        merchant="",
        cadence=cadence,
        monthly_cost=round(typical_amount * monthly_factor, 2),
        last_amount=round(absolute(latest.amount), 2),
        next_expected=add_days(latest.date, cadence_days),
        confidence=round(confidence, 2),
        price_change=price_change,
        status="ACTIVE",
        protected=False,
        transaction_count=len(points)
    );
}


def independently_sum_debits(rows: list[ParsedTransaction]) -> float {
    return round(
        sum(
            [
                0.0 - row.amount
                for row in rows
                if row.amount < 0.0
            ]
        ),
        2
    );
}
