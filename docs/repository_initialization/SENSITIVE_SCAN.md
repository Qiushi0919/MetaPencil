# Sensitive information scan

Run date: 2026-08-24

Command:

```bash
python3 tests/scan_secrets.py
```

Result:

```text
SENSITIVE_SCAN=PASS high_confidence_findings=0
```

Patterns include private-key headers, AWS access keys, GitHub token formats and OpenAI-style keys. A broader assignment-pattern scan produced two MATLAB files using ordinary parser variables named `token/tokens`; manual inspection confirmed they are not credentials.

Binary office/PDF/MAT/STL assets are not fully semantically scanned by this script. Repository visibility must therefore remain private pending licensing and metadata review.

