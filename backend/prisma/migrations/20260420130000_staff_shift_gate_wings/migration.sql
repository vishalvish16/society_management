-- CreateEnum
CREATE TYPE "StaffShift" AS ENUM ('DAY', 'NIGHT', 'FULL');

-- CreateTable
CREATE TABLE "society_gates" (
    "id" TEXT NOT NULL,
    "societyId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "society_gates_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "society_gates_societyId_name_key" ON "society_gates"("societyId", "name");

CREATE INDEX "society_gates_societyId_idx" ON "society_gates"("societyId");

ALTER TABLE "society_gates" ADD CONSTRAINT "society_gates_societyId_fkey" FOREIGN KEY ("societyId") REFERENCES "societies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "staff" ADD COLUMN     "gateId" TEXT,
ADD COLUMN     "shift" "StaffShift" NOT NULL DEFAULT 'FULL',
ADD COLUMN     "assignedWingCodes" JSONB;

CREATE INDEX "staff_gateId_idx" ON "staff"("gateId");

ALTER TABLE "staff" ADD CONSTRAINT "staff_gateId_fkey" FOREIGN KEY ("gateId") REFERENCES "society_gates"("id") ON DELETE SET NULL ON UPDATE CASCADE;
