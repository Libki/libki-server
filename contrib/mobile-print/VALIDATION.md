# Validation and sanitization

Status: Part 2 — Mobile printing. Submitted as a draft upstream contribution for technical review.

Source and screenshots are unchanged from the validated combined draft. This step reorganizes the files and documentation into separate contributions; it does not introduce new feature behavior.

## What was removed or replaced

- The adapter's private service IP and City public service hostname were replaced with reserved example.invalid addresses.
- City-specific credential-file paths and resolver overrides were removed or made generic.
- Production configuration, orchestration, certificates, credentials, patron files, databases, logs, deployment records and private Git history are excluded.
- Test phone numbers use reserved fictional 555-01xx numbers; screenshots use fabricated records and sample documents.
- Library branding and location labels remain as permitted. Prices and pickup locations are examples, not portable configuration defaults.

## Checks completed

- Secret scan of the outbound directory: Gitleaks reported no leaks.
- Targeted scan for private network addresses, City service domains, deployment paths and private key headers: no matches.
- Git diff whitespace check: passed.
- Staff Perl suite: 5 files, 47 top-level tests/subtests passed, including in-memory database acceptance and release/accounting tests.
- Staff browser suite passed: selection limits, quantity and price recalculation, cash reset, reprints, sequential partial results, repeat-click protection and expired-session handling.
- Mobile Python suite: 12 passed, 1 skipped. The skipped case requires a real qpdf merge fixture.
- Mobile browser suite passed: incremental and multiple file selection, retained quantities, five-file limit, removal, canceled selection, filename escaping, phone width and multipart submission.
- Screenshots captured from exported templates/scripts with fabricated records and intercepted HTTP. Test containers had networking disabled. No production printing or payments occurred.

The test environment emitted Catalyst mock-context / SQLite datatype warnings and a FastAPI startup-hook deprecation warning. These were not test failures. Tests used existing isolated dependency images; this was not a fresh end-to-end deployment of the published Dockerfiles. Converter sandboxing, malware scanning, TLS, retention scheduling and real printer integration were not exercised end to end.

## Remaining before a usable public release

The staff changes require compatibility review for existing payment workflows and the release API. Mobile printing still needs generic deployment configuration and verification of its Libki intake integration. Do not describe this snapshot as a drop-in installation.

Automated scanning is evidence, not a guarantee that all sensitive data or security problems have been found. The screenshots were also visually reviewed. This submission remains a draft pending the engineering and compatibility work above.
