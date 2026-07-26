# SpendOS Jac tests

Place server-side Jac tests in this directory using descriptive names such as:

- `import_tests.jac`
- `subscription_tests.jac`
- `precedent_tests.jac`
- `edge_ability_compat_tests.jac`

Run the suite from `spendos/`:

```bash
jac test
```

Avoid `test_*.jac` names for server-side tests because they can conflict with
Python module discovery in the current Jac runtime.
