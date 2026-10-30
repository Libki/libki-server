# Remaining preparation for a usable Part 2 contribution

The sanitized source and screenshots are prepared. These engineering items remain distinct from sanitization:

1. Compare the adapter's upload fields, phone-number-based identification, release-code naming and destination mapping with stock Libki intake. Identify any required Libki server changes and package them explicitly.
2. Replace installation-specific prices and pickup locations with documented settings; ensure displayed and charged prices share a consistent source.
3. Provide a generic deployment example with sample domains, empty secret references, TLS/mutual-TLS setup, isolated conversion/scanning, storage permissions and scheduled expiry cleanup.
4. Build the published Dockerfiles from public dependencies and run an isolated end-to-end upload, conversion, held-job intake and staff-release test.
5. Supply and run the real-PDF merge fixture test; verify antivirus and conversion failure paths as well as cleanup at expiry.
6. Document bundle-copy behavior and confirm interaction with Part 1's staff cash totals.
7. Refresh the screenshot/validation records if behavior changes, rerun disclosure scans, and update the draft contribution for maintainer review.

No real City credentials or network configuration should be copied into examples. Do not describe a phone number as authenticated identity. Do not claim that scanning guarantees a document is harmless.
