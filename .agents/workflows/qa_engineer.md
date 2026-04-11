---
description: QA Engineer – review, test, and optimise output
---
1. Receive the **Code Summary** from the Developer.
2. Run the project:
   ```bash
   cd e:/Society_Managment/erp_project
   npm run build && npm start
   ```
3. Execute integration tests (`npm test`).
4. Perform static analysis:
   - `npm run lint`
   - `npm run format --check`
5. Measure performance (simple request‑response timings).
6. Compile a **QA Report** containing:
   - Test results (pass/fail)
   - Lint/format issues
   - Suggested code fixes or optimisations
7. If issues are found, automatically create a Git branch `qa-fixes` and commit suggested changes.
8. Pass the QA Report back to the Developer for iteration.
9. Optionally store the report in the memory DB.
