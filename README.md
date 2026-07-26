# SpendOS

**An authorization firewall and financial operating system for AI agents that spend money.**

Every payment is a walker. Authorization is a route it must survive.

Built at **JacHacks San Francisco 2026** using Jac and byLLM.

## Plans

- [Simple implementation plan](SIMPLE_PLAN.md) — start small, stay functional, and iterate.
- [Comprehensive product plan](PRODUCT_PLAN.md) — long-term vision, architecture, requirements, and validation.
- [Original technical design](SpendOS.md) — the Jac-native authorization architecture.

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

Jac has Python-like syntax and compiles to Python bytecode, JS, and native code.

```bash
pip install jaclang
jac run main.jac
```

**The features judges are scoring:**

| Feature | What it is |
| --- | --- |
| **Nodes / edges** | Graph-native data topology, first-class in the language |
| **Walkers** | Mobile agents that traverse the graph — computation that moves |
| **`by llm()`** | Replace a function body with an LLM call inferred from names + types. No prompt engineering. |
| **Object-spatial programming** | Dispatch computation by *arrival at a node* |
| **Scale invariance** | Same code runs in a terminal or across a cluster, unchanged |

**Links:**
- Language site — https://www.jac-lang.org/
- Docs — https://www.jaseci.org
- Source — https://github.com/jaseci-labs/jaseci

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
├── README.md      # this file — event details, rules, deadlines
├── IDEAS.md       # idea backlog + the one we picked
├── SUBMISSION.md  # draft the Devpost copy here before pasting
└── src/           # the actual project
```
