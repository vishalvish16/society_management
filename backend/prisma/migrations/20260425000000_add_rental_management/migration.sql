-- CreateEnum
CREATE TYPE "OccupancyType" AS ENUM ('OWNER_OCCUPIED', 'RENTED', 'LEASED', 'VACANT');

-- CreateEnum
CREATE TYPE "AgreementType" AS ENUM ('RENT', 'LEASE', 'LICENSE');

-- AlterTable: add occupancyType to units
ALTER TABLE "units" ADD COLUMN "occupancyType" "OccupancyType" NOT NULL DEFAULT 'OWNER_OCCUPIED';

-- CreateTable
CREATE TABLE "rental_records" (
    "id" TEXT NOT NULL,
    "unitId" TEXT NOT NULL,
    "societyId" TEXT NOT NULL,
    "tenantName" TEXT NOT NULL,
    "tenantPhone" TEXT NOT NULL,
    "tenantEmail" TEXT,
    "tenantAadhaar" TEXT,
    "membersCount" INTEGER NOT NULL DEFAULT 1,
    "ownerUserId" TEXT,
    "tenantUserId" TEXT,
    "agreementType" "AgreementType" NOT NULL DEFAULT 'RENT',
    "rentAmount" DECIMAL(10,2),
    "securityDeposit" DECIMAL(10,2),
    "agreementStartDate" DATE NOT NULL,
    "agreementEndDate" DATE,
    "agreementDocUrl" TEXT,
    "policeVerification" BOOLEAN NOT NULL DEFAULT false,
    "nokName" TEXT,
    "nokPhone" TEXT,
    "notes" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "rental_records_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "rental_records_unitId_idx" ON "rental_records"("unitId");

-- CreateIndex
CREATE INDEX "rental_records_societyId_idx" ON "rental_records"("societyId");

-- AddForeignKey
ALTER TABLE "rental_records" ADD CONSTRAINT "rental_records_unitId_fkey" FOREIGN KEY ("unitId") REFERENCES "units"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rental_records" ADD CONSTRAINT "rental_records_societyId_fkey" FOREIGN KEY ("societyId") REFERENCES "societies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rental_records" ADD CONSTRAINT "rental_records_ownerUserId_fkey" FOREIGN KEY ("ownerUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rental_records" ADD CONSTRAINT "rental_records_tenantUserId_fkey" FOREIGN KEY ("tenantUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
