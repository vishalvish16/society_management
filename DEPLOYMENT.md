# Deployment & Database Migration Guide (Prisma + Postgres)

This repo uses **Prisma Migrate** with **PostgreSQL**.

The #1 rule: **Never reset a database with real data.**

---

## Environments & the correct Prisma command

### Local dev (creating new migrations)
Use `migrate dev` **only** on a dev database you can safely change.

```powershell
cd backend
npx prisma migrate dev
```

- **Do not edit** existing migrations after they are applied anywhere.
- Commit the generated `backend/prisma/migrations/*` folder changes.

### Staging / Production (applying existing migrations)
Use `migrate deploy` (non-interactive, safe, **no reset**).

```bash
cd backend
npx prisma migrate deploy
```

---

## Recommended release sequence (staging/production)

1. **Backup** database (production best practice)
2. Pull new code (or build artifact)
3. Set env vars (at minimum `DATABASE_URL`)
4. Apply migrations:

```bash
cd backend
npx prisma migrate deploy
```

5. Restart backend services

---

## Why `migrate dev` sometimes asks to reset (and why you should say NO)

Prisma may prompt:
> “We need to reset the schema… All data will be lost”

This happens when Prisma detects **drift**, meaning your database schema does not match:
- migration history in `prisma/migrations`, and/or
- checksums stored in `_prisma_migrations`.

Common causes:
- Someone changed DB manually (outside Prisma migrations)
- Someone used `prisma db push` on a shared DB
- A migration SQL file was modified after it was applied

For any DB with real data: **do not reset**.

---

## Safe way to handle drift (no data loss)

### 1) Check migration status

```bash
cd backend
npx prisma migrate status
```

### 2) If drift exists, create a forward “sync” migration

Generate the SQL Prisma expects between live DB and current `schema.prisma`:

```bash
cd backend
npx prisma migrate diff --from-schema-datasource prisma/schema.prisma --to-schema-datamodel prisma/schema.prisma --script
```

Then create a new migration folder and put that SQL into `migration.sql`, commit it, and deploy using:

```bash
npx prisma migrate deploy
```

This is how you “catch up” history to the real DB without deleting data.

---

## CI/CD suggestion (backend)

On deploy jobs (staging/prod):

```bash
cd backend
npm ci
npx prisma generate
npx prisma migrate deploy
node src/server.js
```

---

## Quick checklist for “smooth updates”

- Only one source of truth for schema changes: **Prisma migrations**
- Never edit old migrations
- Use `migrate dev` only for local/dev DBs
- Use `migrate deploy` for staging/prod
- Keep `schema.prisma` and migrations committed together

