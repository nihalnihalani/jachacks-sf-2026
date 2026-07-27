"""Typed SpendOS agent assessment with graph-derived evidence tools."""

import os;

import from schema { AgentAssessment }


obj InvestigationPacket {
    has merchant: str,
        cadence: str,
        monthly_cost: float,
        confidence: float,
        evidence_ids: list[str],
        charge_history: list[str],
        price_changes: list[str],
        preferences: list[str],
        precedents: list[str],
        portfolio_overlap: list[str];
}

sem InvestigationPacket.merchant = "The normalized subscription merchant.";
sem InvestigationPacket.cadence = "The deterministically detected billing cadence.";
sem InvestigationPacket.monthly_cost = "The deterministic monthly-equivalent cost.";
sem InvestigationPacket.confidence = "The deterministic recurrence confidence from zero to one.";
sem InvestigationPacket.evidence_ids = "The only evidence identifiers the assessment may cite.";
sem InvestigationPacket.charge_history = "Charge facts read from the user's transaction graph.";
sem InvestigationPacket.price_changes = "Deterministically calculated price changes.";
sem InvestigationPacket.preferences = "User-authored protection and merchant preferences.";
sem InvestigationPacket.precedents = "Prior decisions for this merchant.";
sem InvestigationPacket.portfolio_overlap = "Other active subscriptions in the same product family.";

def read_charge_history(packet: InvestigationPacket) -> list[str] {
    return packet.charge_history;
}

sem read_charge_history = "Read the subscription's dated charge history from the graph.";
sem read_charge_history.packet = "The graph-derived investigation packet.";


def read_price_changes(packet: InvestigationPacket) -> list[str] {
    return packet.price_changes;
}

sem read_price_changes = "Read deterministic price-change calculations.";
sem read_price_changes.packet = "The graph-derived investigation packet.";


def read_user_preferences(packet: InvestigationPacket) -> list[str] {
    return packet.preferences;
}

sem read_user_preferences = "Read user-authored protection rules and corrections.";
sem read_user_preferences.packet = "The graph-derived investigation packet.";


def read_prior_precedent(packet: InvestigationPacket) -> list[str] {
    return packet.precedents;
}

sem read_prior_precedent = "Read prior user decisions for this merchant.";
sem read_prior_precedent.packet = "The graph-derived investigation packet.";


def compare_portfolio_overlap(packet: InvestigationPacket) -> list[str] {
    return packet.portfolio_overlap;
}

sem compare_portfolio_overlap = "Read overlapping active subscriptions from the graph.";
sem compare_portfolio_overlap.packet = "The graph-derived investigation packet.";


def assess_subscription(packet: InvestigationPacket) -> AgentAssessment by llm(
    tools=[
        read_charge_history,
        read_price_changes,
        read_user_preferences,
        read_prior_precedent,
        compare_portfolio_overlap,

    ],
    temperature=0.1,
    max_tokens=700,
    max_react_iterations=6,
    max_output_retries=2
);

sem assess_subscription = """Assess one subscription using the provided tools.
Use only cited evidence. Never infer that the user does not use a service.
Protected preferences require KEEP. Low confidence or unsupported claims
require REVIEW. CANCEL is allowed only when strong recurrence evidence and
portfolio overlap support presenting a cancellation candidate; the user still
must approve any action.""";

sem assess_subscription.packet = "The complete graph-derived evidence packet.";


def live_agent_available -> bool {
    for key in ["OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GOOGLE_API_KEY"] {
        if os.environ.get(key, "") {
            return True;
        }
    }
    return False;
}


def citations_are_valid(citations: list[str], allowed: list[str]) -> bool {
    if not citations {
        return False;
    }
    for citation in citations {
        if citation not in allowed {
            return False;
        }
    }
    return True;
}
