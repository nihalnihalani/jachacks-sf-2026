"""SpendOS purchase-layer (V7) domain model: catalog, cart, and simulated orders.

Version 7.0 only: parse -> resolve -> cart -> view -> simulate. No gates yet.
"""

import csv;
import os;
import re;


obj CatalogProductView {
    has product_id: str,
        store: str,
        name: str,
        price: float,
        brand: str = "",
        size: str = "",
        currency: str = "USD",
        in_stock: bool = True;
}

obj CartLineView {
    has product_id: str,
        name: str,
        unit_price: float,
        quantity: float,
        line_total: float,
        brand: str = "",
        size: str = "",
        currency: str = "USD";
}

obj CartView {
    has store: str,
        lines: list[CartLineView] = [],
        subtotal: float = 0.0,
        fees: float = 0.0,
        taxes: float = 0.0,
        grand_total: float = 0.0,
        currency: str = "USD";
}

obj CartTotals {
    has subtotal: float,
        fees: float,
        taxes: float,
        grand_total: float;
}

obj SimulatedOrderView {
    has order_id: str,
        store: str,
        lines: list[CartLineView] = [],
        subtotal: float = 0.0,
        fees: float = 0.0,
        taxes: float = 0.0,
        grand_total: float = 0.0,
        currency: str = "USD",
        status: str = "SIMULATED",
        created_at: str = "",
        disclosure: str = "No real charge was made. This order is SIMULATED.";
}

obj PurchaseRequestItem {
    has raw_text: str,
        query: str,
        quantity: float = 1.0,
        quantity_assumed: bool = False;
}

obj ParsedPurchaseInstruction {
    has store: str,
        items: list[PurchaseRequestItem] = [],
        notes: list[str] = [];
}

obj ResolvedPurchaseLine {
    has raw_text: str,
        product_id: str,
        quantity: float,
        quantity_assumed: bool;
}

obj PurchaseResultView {
    has status: str,
        store: str = "",
        order: SimulatedOrderView | None = None,
        notes: list[str] = [],
        unresolved_items: list[str] = [];
}

obj ScoredProduct {
    has score: int,
        product: CatalogProductView;
}

node Cart {
    has cart_id: str,
        store: str,
        created_at: str,
        updated_at: str;
}

node CartLine {
    has line_id: str,
        product_id: str,
        name: str,
        unit_price: float,
        quantity: float,
        brand: str = "",
        size: str = "",
        currency: str = "USD";
}

node PurchaseOrder {
    has order_id: str,
        store: str,
        subtotal: float,
        fees: float,
        taxes: float,
        grand_total: float,
        created_at: str,
        currency: str = "USD",
        status: str = "SIMULATED";
}

node OrderLine {
    has line_id: str,
        product_id: str,
        name: str,
        unit_price: float,
        quantity: float,
        line_total: float,
        brand: str = "",
        size: str = "",
        currency: str = "USD";
}

node AuditEntry {
    has audit_id: str,
        entry: str,
        created_at: str;
}

edge Holds: Cart --> CartLine {}
edge Included: PurchaseOrder --> OrderLine {}
edge LoggedBy: PurchaseOrder --> AuditEntry {}


def catalog_path -> str {
    return os.path.join(os.path.dirname(__file__), "data", "catalog.csv");
}


def load_catalog(store: str = "") -> list[CatalogProductView] {
    normalized_store = store.strip().lower();
    products: list[CatalogProductView] = [];
    with open(catalog_path()) as source {
        reader = csv.DictReader(source);
        for row in reader {
            row_store = str(row.get("store", "")).strip();
            if normalized_store and row_store.lower() != normalized_store {
                continue;
            }
            in_stock_text = str(row.get("in_stock", "true")).strip().lower();
            products.append(
                CatalogProductView(
                    product_id=str(row.get("product_id", "")).strip(),
                    store=row_store,
                    name=str(row.get("name", "")).strip(),
                    brand=str(row.get("brand", "")).strip(),
                    size=str(row.get("size", "")).strip(),
                    price=round(float(str(row.get("price", "0")).strip() or "0"), 2),
                    currency=str(row.get("currency", "USD")).strip() or "USD",
                    in_stock=in_stock_text in ["true", "1", "yes"]
                )
            );
        }
    }
    return products;
}


def match_score(query_tokens: list[str], product: CatalogProductView) -> int {
    haystack = f"{product.name} {product.brand} {product.size}".lower();
    score = 0;
    for token in query_tokens {
        if token in haystack {
            score += 1;
        }
    }
    return score;
}


def search_catalog(store: str, query: str) -> list[CatalogProductView] {
    query_tokens: list[str] = [
        token
        for token in re.findall(r"[a-z]+", query.lower())
        if len(token) > 1
    ];
    if not query_tokens {
        return [];
    }
    scored: list[ScoredProduct] = [];
    for product in load_catalog(store) {
        score = match_score(query_tokens, product);
        if score > 0 {
            scored.append(ScoredProduct(score=score, product=product));
        }
    }
    ranked = sorted(
        scored,
        key=lambda (item: ScoredProduct) { (0 - item.score, item.product.price); }
    );
    return [item.product for item in ranked][0:5];
}


def normalize_store_name(value: str) -> str {
    return value.strip().rstrip(".!?").strip();
}


def parse_purchase_instruction(
    instruction: str, default_store: str = "Instacart"
) -> ParsedPurchaseInstruction {
    text = instruction.strip();
    if not text {
        raise ValueError("A purchase instruction is required.");
    }
    words: list[str] = text.split();
    if words and words[0].lower() in ["buy", "order", "purchase", "get"] {
        words = words[1:];
    }
    remainder: str = " ".join(words);
    notes: list[str] = [];
    store: str = default_store;
    item_text: str = remainder;
    lower_remainder: str = remainder.lower();
    from_index: int = lower_remainder.rfind(" from ");
    if from_index >= 0 {
        store = normalize_store_name(remainder[from_index + 6:]);
        item_text = remainder[0:from_index].strip().rstrip(",");
    } else {
        notes.append(
            f"No store named in the instruction; defaulting to {default_store}."
        );
    }
    item_text = item_text.replace(", and ", ", ").replace(" and ", ", ");
    items: list[PurchaseRequestItem] = [];
    for piece in item_text.split(",") {
        raw: str = piece.strip();
        if not raw {
            continue;
        }
        quantity: float = 1.0;
        quantity_assumed: bool = True;
        first_word: str = raw.split()[0] if raw.split() else "";
        if first_word.replace(".", "", 1).isdigit() {
            quantity = float(first_word);
            quantity_assumed = False;
        }
        items.append(
            PurchaseRequestItem(
                raw_text=raw,
                query=raw,
                quantity=quantity,
                quantity_assumed=quantity_assumed
            )
        );
    }
    if not items {
        raise ValueError("No purchasable items were found in the instruction.");
    }
    return ParsedPurchaseInstruction(store=store, items=items, notes=notes);
}


def compute_cart_totals(lines: list[CartLineView]) -> CartTotals {
    subtotal: float = 0.0;
    for line in lines {
        subtotal += line.line_total;
    }
    subtotal = round(subtotal, 2);
    fees: float = 4.99 if lines else 0.0;
    taxes: float = 0.0;
    grand_total: float = round(subtotal + fees + taxes, 2);
    return CartTotals(subtotal=subtotal, fees=fees, taxes=taxes, grand_total=grand_total);
}
