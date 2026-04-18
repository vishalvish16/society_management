DROP INDEX IF EXISTS "maintenance_bills_unitId_billingMonth_key";

CREATE UNIQUE INDEX "maintenance_bills_unitId_billingMonth_active_key"
ON "maintenance_bills"("unitId", "billingMonth")
WHERE "deletedAt" IS NULL;
