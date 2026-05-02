-- This migration was created manually to sync an existing database to the current Prisma schema
-- without resetting data. It contains the SQL diff between the live DB and `schema.prisma`.

-- DropForeignKey
ALTER TABLE "complaints" DROP CONSTRAINT "complaints_unitId_fkey";

-- DropForeignKey
ALTER TABLE "estimates" DROP CONSTRAINT "estimates_planId_fkey";

-- DropForeignKey
ALTER TABLE "suggestions" DROP CONSTRAINT "suggestions_unitId_fkey";

-- AlterTable
ALTER TABLE "estimates" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- AlterTable
ALTER TABLE "pricing_tiers" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- AlterTable
ALTER TABLE "societies" ADD COLUMN     "maxUnits" INTEGER,
ADD COLUMN     "maxUsers" INTEGER;

-- CreateTable
CREATE TABLE "staff_salary_payments" (
    "id" TEXT NOT NULL,
    "societyId" TEXT NOT NULL,
    "staffId" TEXT NOT NULL,
    "periodFrom" DATE NOT NULL,
    "periodTo" DATE NOT NULL,
    "divisorDays" INTEGER NOT NULL,
    "rules" JSONB,
    "amount" DECIMAL(10,2) NOT NULL,
    "paymentMethod" "PaymentMethod" NOT NULL DEFAULT 'CASH',
    "note" TEXT,
    "paidAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "paidById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "staff_salary_payments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "staff_salary_payments_societyId_periodFrom_periodTo_idx" ON "staff_salary_payments"("societyId", "periodFrom", "periodTo");

-- CreateIndex
CREATE INDEX "staff_salary_payments_staffId_idx" ON "staff_salary_payments"("staffId");

-- CreateIndex
CREATE UNIQUE INDEX "staff_salary_payments_societyId_staffId_periodFrom_periodTo_key" ON "staff_salary_payments"("societyId", "staffId", "periodFrom", "periodTo");

-- AddForeignKey
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_unitId_fkey" FOREIGN KEY ("unitId") REFERENCES "units"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "suggestions" ADD CONSTRAINT "suggestions_unitId_fkey" FOREIGN KEY ("unitId") REFERENCES "units"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff_salary_payments" ADD CONSTRAINT "staff_salary_payments_societyId_fkey" FOREIGN KEY ("societyId") REFERENCES "societies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff_salary_payments" ADD CONSTRAINT "staff_salary_payments_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff_salary_payments" ADD CONSTRAINT "staff_salary_payments_paidById_fkey" FOREIGN KEY ("paidById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "estimates" ADD CONSTRAINT "estimates_planId_fkey" FOREIGN KEY ("planId") REFERENCES "plans"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

