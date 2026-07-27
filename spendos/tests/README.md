# SpendOS tests

The Jac suite covers the product's deterministic and graph-persistence
contracts. Run it from `spendos/`:

```bash
jac clean --data --force
jac test
```

Files deliberately use the `*_tests.jac` naming convention because
`test_*.jac` conflicts with Jac's server-side test discovery.
