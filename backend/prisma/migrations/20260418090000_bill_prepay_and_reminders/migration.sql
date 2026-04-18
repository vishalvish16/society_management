ALTER TABLE "units"
ADD COLUMN "prepaidUntil" TIMESTAMP(3);

ALTER TABLE "maintenance_bills"
ADD COLUMN "coverageFrom" TIMESTAMP(3),
ADD COLUMN "coverageTo" TIMESTAMP(3),
ADD COLUMN "lastReminderAt" TIMESTAMP(3);
