-- Add cancellation/undo fields for salary payments

-- AlterTable
ALTER TABLE "staff_salary_payments"
ADD COLUMN     "cancelReason" TEXT,
ADD COLUMN     "cancelledAt" TIMESTAMP(3),
ADD COLUMN     "cancelledById" TEXT;

-- CreateIndex
CREATE INDEX "staff_salary_payments_societyId_cancelledAt_idx"
ON "staff_salary_payments"("societyId", "cancelledAt");

-- AddForeignKey
ALTER TABLE "staff_salary_payments"
ADD CONSTRAINT "staff_salary_payments_cancelledById_fkey"
FOREIGN KEY ("cancelledById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

