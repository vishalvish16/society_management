-- Add Cash/Bank ledger support

-- CreateEnum
CREATE TYPE "LedgerAccount" AS ENUM ('CASH', 'BANK');

-- CreateEnum
CREATE TYPE "LedgerDirection" AS ENUM ('IN', 'OUT');

-- AlterTable
ALTER TABLE "expenses" ADD COLUMN IF NOT EXISTS "paymentMethod" "PaymentMethod";

-- CreateTable
CREATE TABLE IF NOT EXISTS "ledger_entries" (
    "id" TEXT NOT NULL,
    "societyId" TEXT NOT NULL,
    "account" "LedgerAccount" NOT NULL,
    "direction" "LedgerDirection" NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "occurredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "description" TEXT,
    "transferGroupId" TEXT,
    "createdById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ledger_entries_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "ledger_entries_societyId_occurredAt_idx" ON "ledger_entries"("societyId", "occurredAt");

-- CreateIndex
CREATE INDEX IF NOT EXISTS "ledger_entries_societyId_account_occurredAt_idx" ON "ledger_entries"("societyId", "account", "occurredAt");

-- CreateIndex
CREATE INDEX IF NOT EXISTS "ledger_entries_transferGroupId_idx" ON "ledger_entries"("transferGroupId");

-- AddForeignKey
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ledger_entries_societyId_fkey'
  ) THEN
    ALTER TABLE "ledger_entries"
      ADD CONSTRAINT "ledger_entries_societyId_fkey"
      FOREIGN KEY ("societyId") REFERENCES "societies"("id")
      ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

-- AddForeignKey
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ledger_entries_createdById_fkey'
  ) THEN
    ALTER TABLE "ledger_entries"
      ADD CONSTRAINT "ledger_entries_createdById_fkey"
      FOREIGN KEY ("createdById") REFERENCES "users"("id")
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

