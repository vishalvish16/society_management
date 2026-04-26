-- Add missing pricing columns for legacy databases.
-- Some environments were created without priceMonthly/priceYearly but the Prisma model expects them.
ALTER TABLE "plans" ADD COLUMN IF NOT EXISTS "priceMonthly" DECIMAL(10,2) NOT NULL DEFAULT 0;
ALTER TABLE "plans" ADD COLUMN IF NOT EXISTS "priceYearly" DECIMAL(10,2) NOT NULL DEFAULT 0;

