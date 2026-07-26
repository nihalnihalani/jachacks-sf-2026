"""SpendOS — full-stack entry point.

The client half. Deliberately decoupled from `schema.jac` / `gates.jac` for
now: the UI runs off its scripted mock path so the frontend can never be
broken by an in-flight backend edit. Wiring the real walkers is a one-line
change in `frontend.impl.jac` — see the note there.
"""

# Importing the walker here MOUNTS it on the web-app server and makes it
# reachable from the client codespace via `sv import`.
import from endpoints { ScreenPayment, ResetDemo }

cl {
    import from .frontend { app as SpendOSApp }

    def:pub app -> JsxElement {
        return <SpendOSApp/>;
    }
}
