# Current Jac book recommender

A compact current-syntax example showing:

- nodes and a typed edge;
- walker traversal;
- a real `by llm()` recommendation function;
- a semstring;
- typed walker reports;
- the primary `node spawn Walker()` form.

Run after installing Jac:

```bash
export OPENAI_API_KEY="..."
jac install
jac check
jac run main.jac
```

The LLM receives only the books connected to the user through `Candidate`
edges and returns exact titles from that catalog.
