"""SpendOS purchase-layer (V7.0) tests: simulated order, no gates yet."""

import from purchase {
    AuditEntry,
    parse_purchase_instruction,
    search_catalog,
}
import from endpoints {
    PurchaseOrder,
    add_to_cart,
    place_purchase,
    record_audit,
    resolve_products,
    simulate_order,
    view_cart,
}


def clear_graph {
    for item in [root-->] {
        del item;
    }
}


test "purchase instruction parses store quantity and assumptions" {
    parsed = parse_purchase_instruction("buy 1 kg potato, onion, and tomato from Instacart");
    assert parsed.store == "Instacart";
    assert len(parsed.items) == 3;
    assert parsed.items[0].quantity == 1.0;
    assert not parsed.items[0].quantity_assumed;
    assert parsed.items[1].raw_text == "onion";
    assert parsed.items[1].quantity == 1.0;
    assert parsed.items[1].quantity_assumed;
    assert parsed.items[2].raw_text == "tomato";
}


test "purchase instruction without a store defaults and notes it" {
    parsed = parse_purchase_instruction("buy 2 eggs", default_store="Instacart");
    assert parsed.store == "Instacart";
    assert len(parsed.notes) == 1;
    assert "defaulting to Instacart" in parsed.notes[0];
}


test "resolve products finds the closest catalog match" {
    candidates = search_catalog("Instacart", "1 kg potato");
    assert len(candidates) >= 1;
    assert candidates[0].name == "Potato";
    assert candidates[0].in_stock;

    avocado = search_catalog("Instacart", "avocado");
    assert len(avocado) == 1;
    assert not avocado[0].in_stock;
}


test "cart and order totals are recomputed from live catalog data" {
    clear_graph();
    potato = resolve_products("Instacart", "1 kg potato")[0];
    onion = resolve_products("Instacart", "onion")[0];
    add_to_cart("Instacart", potato.product_id, 1.0);
    cart = add_to_cart("Instacart", onion.product_id, 1.0);
    assert len(cart.lines) == 2;
    expected_subtotal: float = round(potato.price + onion.price, 2);
    assert cart.subtotal == expected_subtotal;
    assert cart.fees == 4.99;
    assert cart.grand_total == round(expected_subtotal + 4.99, 2);

    viewed = view_cart("Instacart");
    assert viewed.grand_total == cart.grand_total;

    order = simulate_order("Instacart");
    assert order.status == "SIMULATED";
    assert order.grand_total == cart.grand_total;
    assert len(order.lines) == 2;
    assert len([root-->[?:PurchaseOrder, order_id==order.order_id]]) == 1;

    emptied = view_cart("Instacart");
    assert len(emptied.lines) == 0;
}


test "simulate order refuses an empty cart" {
    clear_graph();
    try {
        simulate_order("Instacart");
        assert False, "should have raised";
    } except ValueError {
        assert True;
    }
}


test "record audit appends an entry" {
    clear_graph();
    audit_id = record_audit("ORDER order_test at Instacart: 1 item, SIMULATED.");
    entries: list[AuditEntry] = [root-->[?:AuditEntry, audit_id==audit_id]];
    assert len(entries) == 1;
    assert "SIMULATED" in entries[0].entry;
}


test "place purchase produces a correct simulated order from live catalog data" {
    clear_graph();
    result = place_purchase("buy 1 kg potato, onion, and tomato from Instacart");
    assert result.status == "SIMULATED";
    assert result.store == "Instacart";
    assert result.order is not None;
    order = result.order;
    assert order.status == "SIMULATED";
    assert len(order.lines) == 3;
    line_names = sorted([line.name for line in order.lines]);
    assert line_names == sorted(["Roma Tomato", "Potato", "Yellow Onion"]);

    line_total_sum: float = round(
        sum([line.unit_price * line.quantity for line in order.lines]), 2
    );
    expected_total: float = round(line_total_sum + 4.99, 2);
    assert order.grand_total == expected_total;

    assert any(["Assumed quantity 1 for 'onion'" in note for note in result.notes]);
    assert any(["Assumed quantity 1 for 'tomato'" in note for note in result.notes]);

    audits: list[AuditEntry] = [root-->[?:AuditEntry]];
    assert len(audits) == 1;
    assert order.order_id in audits[0].entry;
    assert "SIMULATED" in audits[0].entry;

    orders: list[PurchaseOrder] = [root-->[?:PurchaseOrder]];
    assert len(orders) == 1;
    assert orders[0].status == "SIMULATED";
}


test "out of stock item is reported and never auto-substituted" {
    clear_graph();
    result = place_purchase("buy avocado from Instacart");
    assert result.status == "NEEDS_INPUT";
    assert len(result.unresolved_items) == 1;
    assert "out of stock" in result.unresolved_items[0];
    assert result.order is None;
    assert len([root-->[?:PurchaseOrder]]) == 0;
    assert len([root-->[?:AuditEntry]]) == 0;

    cart = view_cart("Instacart");
    assert len(cart.lines) == 0;
}


test "unresolvable item blocks the whole order rather than partially buying" {
    clear_graph();
    result = place_purchase("buy potato and unobtainium from Instacart");
    assert result.status == "NEEDS_INPUT";
    assert len(result.unresolved_items) == 1;
    assert "No catalog match" in result.unresolved_items[0];
    assert result.order is None;
    assert len([root-->[?:PurchaseOrder]]) == 0;

    cart = view_cart("Instacart");
    assert len(cart.lines) == 0;
}
