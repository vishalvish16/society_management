---
description: Developer – generate production‑ready code
---
1. Load the **Architecture Blueprint** from `e:/Society_Managment/.agents/blueprint.json`.
2. Scaffold the project directory `e:/Society_Managment/erp_project`:
   - `npm init -y`
   - Install dependencies (`express`, `prisma`, `@prisma/client`, `dotenv`, `typescript`, `ts-node`, `eslint`, `prettier`).
3. Create Prisma schema based on the blueprint and run `npx prisma migrate dev`.
4. Generate TypeScript source files for each module:
   - Controllers, services, routes, DTOs.
   - Add OpenAPI annotations if desired.
5. Add basic unit tests (Jest) for each endpoint.
6. Run lint (`npm run lint`) and format (`npm run format`).
7. Commit the initial code:
   ```bash
   git init && git add . && git commit -m "Initial scaffold from Architect blueprint"
   ```
8. Output a **Code Summary** (list of generated files, key endpoints) and hand it to the QA Engineer.
9. (Optional) Store the summary in the memory DB.
