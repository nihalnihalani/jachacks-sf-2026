"""SpendOS server endpoints.

The client calls these with `root spawn` across the codespace boundary --
no fetch, no REST client, no Express. That cross-codespace call is the
"single-file dev" criterion, and it is what Sentinel structurally could not
claim: it shipped 4,479 lines of React plus an Express server to do what
this file does in forty.
"""

import from gates { seed_spendos, reset_spendos }
import from schema { Payment }

walker:pub ScreenPayment {
    """Screen one payment through the live gate chain."""
    has payment_id: str = "",
        amount: float = 0.0,
        merchant: str = "",
        category: str = "",
        reports: list[dict] = [];

    can screen with Root entry {
        tre = seed_spendos();
        pay = Payment(
            payment_id=self.payment_id, amount=self.amount,
            merchant=self.merchant, category=self.category,
            cart={"category": self.category, "merchant": self.merchant,
                  "total": self.amount}
        );
        tre spawn pay;
        report pay.outcome();
    }
}

walker:pub ResetDemo {
    """Reset transient state so a rehearsal starts clean.

    Velocity counters and treasury spend accumulate by design -- that is what
    makes the structuring attack work. But it means the Nth click of the same
    button hits a different gate than the first, which on stage reads as a
    bug rather than as accumulation. The UI calls this between runs.

    Precedent nodes deliberately SURVIVE (see reset_spendos in gates.jac):
    the system forgets the window, not the lesson. That asymmetry is the
    'it learned' beat.
    """
    has reports: list[str] = [];

    can reset with Root entry {
        reset_spendos();
        seed_spendos();
        report "reset";
    }
}
