"""SpendOS full-stack entry point."""

import from endpoints {
    AnalyzePortfolio,
    BudgetView,
    Decision,
    DecideCase,
    ImportStatement,
    InvestigateSubscription,
    SimulatedAction,
    SimulateCancellation,
    PurchaseProposalView,
    ShoppingCandidateView,
    ShoppingCandidateInput,
    ShoppingMissionView,
    SubscriptionCase,
    add_to_cart,
    decide_purchase_proposal,
    claim_shopping_mission,
    complete_shopping_mission,
    create_shopping_mission,
    get_dashboard,
    get_synthetic_feed,
    place_purchase,
    preview_statement,
    propose_purchase,
    record_audit,
    reset_demo_data,
    resolve_products,
    save_budget_plan,
    simulate_order,
    simulate_purchase,
    submit_shopping_candidate,
    view_cart,
}

cl {
    import from .frontend { app as SpendOSApp }

    def:pub app -> JsxElement {
        return <SpendOSApp/>;
    }
}
