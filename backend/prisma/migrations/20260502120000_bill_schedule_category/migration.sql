-- Add bill schedule category (maintenance vs parking auto-generation).
ALTER TABLE "maintenance_bill_schedules" ADD COLUMN IF NOT EXISTS "category" TEXT NOT NULL DEFAULT 'MAINTENANCE';

DROP INDEX IF EXISTS "maintenance_bill_schedules_societyId_billingMonth_key";

CREATE UNIQUE INDEX "maintenance_bill_schedules_societyId_billingMonth_category_key"
  ON "maintenance_bill_schedules"("societyId", "billingMonth", "category");
