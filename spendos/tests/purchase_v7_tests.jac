"""Focused Version 7.0 purchase-layer contract tests."""

import from purchase {
    CartLineView,
    compute_cart_totals,
    parse_purchase_instruction,
    search_catalog,
}


test "purchase instruction preserves quantities and store" {
    parsed = parse_purchase_instruction(
        "buy 1 kg potato, onion, and tomato from Instacart"
    );
    assert parsed.store == "Instacart";
    assert len(parsed.items) == 3;
    assert parsed.items[0].quantity == 1.0;
    assert not parsed.items[0].quantity_assumed;
    assert parsed.items[1].quantity == 1.0;
    assert parsed.items[1].quantity_assumed;
}


test "purchase instruction labels its default store assumption" {
    parsed = parse_purchase_instruction("buy sourdough bread");
    assert parsed.store == "Instacart";
    assert len(parsed.notes) == 1;
    assert "defaulting" in parsed.notes[0];
}


test "simulated catalog returns authoritative local records" {
    potato = search_catalog("Instacart", "1 kg potato");
    unavailable = search_catalog("Instacart", "avocado");
    assert potato;
    assert potato[0].product_id == "inst-potato-1kg";
    assert potato[0].price == 3.49;
    assert unavailable;
    assert not unavailable[0].in_stock;
}

test "target chocolate demo resolves an exact six count product" {
    chocolate = search_catalog("Target", "half a dozen assorted chocolate");
    assert chocolate;
    assert chocolate[0].product_id == "target-chocolate-assorted-6";
    assert chocolate[0].size == "6 count";
    assert chocolate[0].in_stock;
}


test "cart totals are recomputed from line items" {
    lines: list[CartLineView] = [
        CartLineView(
            product_id="first",
            name="First",
            unit_price=3.49,
            quantity=2.0,
            line_total=6.98
        ),
        CartLineView(
            product_id="second",
            name="Second",
            unit_price=1.29,
            quantity=1.0,
            line_total=1.29
        ),
    ];
    totals = compute_cart_totals(lines);
    assert totals.subtotal == 8.27;
    assert totals.fees == 4.99;
    assert totals.taxes == 0.0;
    assert totals.grand_total == 13.26;
}
