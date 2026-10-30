# Staff print selection and cash collection — draft contribution

This adds a staff review step for held print jobs: select up to 20 jobs on the current page, choose 1–99 copies per job, review the combined price and pages, confirm cash collected, and release jobs sequentially. Changing a quantity resets cash confirmation. Results are shown per job, including failures and uncertain submissions. Additional reprints require a separate review and cash confirmation.

The server revalidates prices and location, conditionally claims jobs before submission, and guards accounting and repeated release. Print-system acceptance is not confirmation of physical output.

## Scope and compatibility

This is Part 1 of a two-part printing proposal. It does not need the companion mobile service to review existing held jobs. It is separate from the staff screen-viewer and Entra contributions.

This export changes the staff release API to require POST and cash confirmation. CUPS release is gated by `staff_print_release: enabled` in the printer configuration; its default is disabled. Existing account payments, public self-service printing, external API callers, and the opt-in behavior need upstream review before general deployment. These changes are a draft, not an official Libki release.

## Screenshots

[Seven feature screenshots and captions](https://github.com/jhansen123456/libkimods/blob/b8e7b4e80422a05353e6ad9097d867f4aa73a737/contributions/printing/part-1-staff-print-cash/SCREENSHOTS.md)

![Selected documents with individual copies and a combined total](https://raw.githubusercontent.com/jhansen123456/libkimods/b8e7b4e80422a05353e6ad9097d867f4aa73a737/contributions/printing/part-1-staff-print-cash/screenshots/03-staff-per-document-copies.png)

Screenshots were captured from the exported UI using fabricated records and intercepted HTTP. No patron data or live printing was used. The UI uses the upstream styling; the library deployment has additional unrelated customizations.

## Validation

The recorded isolated run passed five Perl test files (47 top-level tests/subtests), including in-memory database acceptance and release/accounting checks:

~~~sh
prove -l t/printing_acceptance.t t/printing_db_acceptance.t t/utils_Printing-create_print_job_and_file.t t/utils_Printing-release.t t/utils_Printing-cancel.t
~~~

The browser harness is t/printing_batch_browser.py. It requires Playwright and browser dependencies, with this checkout available at /work. The recorded run used an isolated prebuilt test image with networking disabled; this is not a clean deployment-build result.

Browser checks covered quantity changes, selection limits, price recalculation, cash reset, reprint review, sequential partial results, repeated submissions, and expired sessions. No production printer or payment transaction was used.

[Full validation record](https://github.com/jhansen123456/libkimods/blob/b8e7b4e80422a05353e6ad9097d867f4aa73a737/contributions/printing/part-1-staff-print-cash/VALIDATION.md)

Catalyst mock-context and SQLite datatype warnings occurred without test failures. End-to-end printing with a real printer and compatibility with other payment integrations remain required.

## Provenance

Prepared against upstream 6acf2d1327efcae92fda3509163a9a1da54b99f2. Only selected changes were exported. No private Git history, credentials, production configuration, patron documents, or database contents are included. Source behavior is unchanged from the sanitized libkimods review package.
