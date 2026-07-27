# SpendOS

**A quiet financial agent that finds waste, protects subscriptions, and learns
what matters to you.**

Start with a real statement. SpendOS finds recurring charges, investigates the
important ones, and turns them into a trustworthy action inbox. Its Jac-native
authorization system remains the foundation for controlled agent spending.

Built at **JacHacks San Francisco 2026** using Jac and byLLM.

## Agent Jac tooling

The shared [Jac Codex setup](docs/jac-codex.md) connects the compiler through
MCP, exports version-matched guides, and installs the repository's
[`jac-codex`](plugins/jac-codex/) plugin with automatic post-edit validation.
Run `./scripts/setup-jac-codex.sh` once, then restart Codex.

## Agent UI tooling

The repository includes shared [21st.dev agent setup](docs/21st.md) for
exploring, building, reviewing, and publishing UI consistently across the
team. Run `./scripts/setup-21st.sh` once after exporting `API_KEY_21ST`; never
commit the real key.

## Plans

- [Simple implementation plan](SIMPLE_PLAN.md) — build one working Subscription Guardian loop.
- [Comprehensive product plan](PRODUCT_PLAN.md) — product strategy, Jac-native architecture, requirements, and validation.
- [Original technical design](SpendOS.md) — the Jac-native authorization architecture.

## Jac reference corpus

The [`Jac docs`](Jac%20docs/README.md) folder is a self-contained reference
library for developers and LLM coding agents. It includes curated setup and
language guidance, runnable examples, papers, and pinned official Jac source
repositories.

Clone the complete corpus, including its pinned upstream repositories, with:

```bash
git clone --recurse-submodules https://github.com/nihalnihalani/jachacks-sf-2026.git
```

---

## Hackathon context

Team repo for **JacHacks San Francisco** — a one-day, in-person AI hackathon built around
[Jac](https://www.jac-lang.org/), the AI-native programming language from Jaseci Labs.

- 🗓️ **Sunday, July 26, 2026**
- 📍 **Founders, Inc. — SF Lab**, 2 Marina Blvd B300, San Francisco, CA 94123
- 🔗 [Luma event](https://luma.com/9x1573sw?tk=6Ez4kx) · [Devpost](https://jachacks-sf.devpost.com/)
- 💰 **$9,000+ in cash prizes**

---

## Team

| GitHub | Role |
| --- | --- |
| [@nihalnihalani](https://github.com/nihalnihalani) | — |
| [@mayu99](https://github.com/mayu99) | — |
| [@yhinai](https://github.com/yhinai) | — |

Max team size is **4**.

---

## Schedule (PT)

| Time | What |
| --- | --- |
| 10:45 AM | Hacking starts (building hours open) |
| — | Keynote — Prof. Jason Mars |
| — | Tech recruiting workshop — Jeff Nguyen |
| — | YC application workshop — Mehul (Koyal AI) |
| **5:50 PM** | ⚠️ **Partial submission checkpoint** (required) |
| **7:15 PM** | 🚨 **Hard final deadline** |
| after | In-person demos — 3 min pitch, ≥1 team member present |

> The 5:50 PM partial submission is not optional. Get *something* on Devpost by then.

---

## Tracks

Pick one at submission time.

| Track | 1st | 2nd |
| --- | --- | --- |
| **Agentic AI** | $2,000 | $1,000 |
| **Fintech / Open** | $1,500 | $800 |
| **Social Impact** | $1,500 | $800 |
| **AI for Defense** | $500 | — |

### Bonus prizes
- **Best JacHammer** — $500
- **Best Use of Jaclang** — $400

---

## Judging criteria

1. **Technical execution** — code quality, sound architecture, a demo that doesn't crash
2. **Use of Jac & Jaseci** — depth on `by llm()`, walkers, graph-native modeling, single-file dev
3. **Creativity & innovation** — fresh, original approach
4. **Presentation & demo** — clear, engaging 3-minute pitch
5. **Impact & novelty** — real problem, grounded approach
6. **Depth of agentic behavior** — planning, memory, tool use, or multi-agent coordination

Judges include folks from **Salesforce, Apple, and Google** — plus Ponita Ty. Referrals are on the table.

---

## Rules & submission requirements

**Hard requirements:**
- The project must **meaningfully use Jac**.
- **All code written during hacking hours** — commits must land inside the window.
- Public GitHub repo (this one).
- Team of up to 4.
- US participants, above the legal age of majority.

**Devpost submission needs:**
- [ ] Project name + description (explicitly describe how Jac is used)
- [ ] Link to this public repo
- [ ] Track selection
- [ ] Demo video — **1:30 max**
- [ ] Partial submission by 5:50 PM
- [ ] Show up in person for the demo

---

## Jac quickstart

Jac ships as one native binary and compiles to Python bytecode, JavaScript, and
native machine code. No external Python installation is required for the native
binary.

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
cd spendos
jac install --plan
jac install
jac precommit
jac test
jac start --dev
```

For current, compiler-matched language guidance:

```bash
jac guide
jac guide --search walker
jac mcp --inspect
```

**The features judges are scoring:**

| Feature | What it is |
| --- | --- |
| **Nodes / edges** | Graph-native data topology, first-class in the language |
| **Walkers** | Mobile agents that traverse the graph — computation that moves |
| **`by llm()`** | Replace a function body with an LLM call inferred from names + types. No prompt engineering. |
| **Object-spatial programming** | Dispatch computation by *arrival at a node* |
| **Scale invariance** | Same code runs in a terminal or across a cluster, unchanged |

**Official references:**
- Language reference — https://docs.jaseci.org/reference/
- Quick guide — https://docs.jaseci.org/quick-guide/
- Release notes — https://docs.jaseci.org/community/release_notes/jaclang/
- Source — https://github.com/jaseci-labs/jac

The `by llm()` + walkers combination is the shortest path to scoring well on both
"Use of Jac & Jaseci" and "Depth of agentic behavior" at once.

---

## Sponsors

NVIDIA · Google DeepMind · Base44 · Lovable · Koyal AI · NSF

---

## Event context

- Third JacHacks. Prior events: 500+ hackers, 150+ projects shipped, 20+ universities.
- 15+ recruiting startups evaluating projects on-site.
- Meals provided.
- Hosts: Vatsal Shah, Jason Mars, Lingjia Tang, Ponita Ty, Jayanaka Dantanarayana, Mike Shin.

---

## Repo layout

```
.
├── README.md          # project and event overview
├── SIMPLE_PLAN.md     # incremental product contract
├── PRODUCT_PLAN.md    # product and architecture direction
└── spendos/
    ├── schema.jac     # graph model and deterministic financial logic
    ├── agent.jac      # typed byLLM investigation and evidence tools
    ├── endpoints.sv.jac
    ├── frontend.cl.jac
    ├── main.jac
    ├── data/sample_statement.csv
    └── tests/core_tests.jac
```
