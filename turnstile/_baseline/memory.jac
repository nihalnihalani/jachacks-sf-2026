import from schema { Precedent }

def match_precedent(fp: str) -> Precedent | None {
    for p in [root --> ][?:Precedent] {
        if p.fingerprint == fp { p.hit_count += 1; return p; }
    }
    return None;
}

def write_precedent(fp: str, verdict: str, reason: str) -> Precedent {
    ex = match_precedent(fp);
    if ex { return ex; }
    p = Precedent(fingerprint=fp, verdict=verdict, reason=reason);
    root ++> p;
    return p;
}

with entry:__main__ {
    write_precedent("acme|giftcard|340", "BLOCKED", "gift card not groceries");
    m = match_precedent("acme|giftcard|340");
    print(f"memory ok: {m.verdict} hits={m.hit_count}");
}
