-- CreateEnum
DO $$ BEGIN
  CREATE TYPE "GatePassDecision" AS ENUM ('APPROVED', 'REJECTED');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- AlterTable
ALTER TABLE "gate_passes"
ADD COLUMN     "decision" "GatePassDecision",
ADD COLUMN     "decisionNote" TEXT;

-- CreateTable
CREATE TABLE "gate_pass_logs" (
    "id" TEXT NOT NULL,
    "gatePassId" TEXT NOT NULL,
    "scannedById" TEXT,
    "result" TEXT NOT NULL,
    "decision" "GatePassDecision",
    "note" TEXT,
    "scannedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gate_pass_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "gate_pass_logs_gatePassId_idx" ON "gate_pass_logs"("gatePassId");

-- CreateIndex
CREATE INDEX "gate_pass_logs_scannedById_idx" ON "gate_pass_logs"("scannedById");

-- AddForeignKey
ALTER TABLE "gate_passes" ADD CONSTRAINT "gate_passes_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gate_passes" ADD CONSTRAINT "gate_passes_scannedById_fkey" FOREIGN KEY ("scannedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gate_pass_logs" ADD CONSTRAINT "gate_pass_logs_gatePassId_fkey" FOREIGN KEY ("gatePassId") REFERENCES "gate_passes"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gate_pass_logs" ADD CONSTRAINT "gate_pass_logs_scannedById_fkey" FOREIGN KEY ("scannedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

