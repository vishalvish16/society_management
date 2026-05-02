-- Migration: pricing_tiers_estimates
-- Adds: PricingTier (tiered per-unit pricing per plan), Estimate (pre-sales CRM), EstimateStatus enum

-- EstimateStatus enum
CREATE TYPE "EstimateStatus" AS ENUM ('DRAFT', 'SENT', 'ACCEPTED', 'REJECTED', 'CLOSED');

-- PricingTier: tiered rate card per plan
CREATE TABLE "pricing_tiers" (
    "id"           TEXT NOT NULL,
    "planId"       TEXT NOT NULL,
    "minUnits"     INTEGER NOT NULL,
    "maxUnits"     INTEGER NOT NULL,
    "pricePerUnit" DECIMAL(10,2) NOT NULL,
    "label"        TEXT,
    "sortOrder"    INTEGER NOT NULL DEFAULT 0,
    "createdAt"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pricing_tiers_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "pricing_tiers" ADD CONSTRAINT "pricing_tiers_planId_fkey"
    FOREIGN KEY ("planId") REFERENCES "plans"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Estimate: pre-sales CRM
CREATE TABLE "estimates" (
    "id"              TEXT NOT NULL,
    "estimateNumber"  TEXT NOT NULL,
    "societyName"     TEXT NOT NULL,
    "contactPerson"   TEXT,
    "contactPhone"    TEXT,
    "contactEmail"    TEXT,
    "city"            TEXT,
    "unitCount"       INTEGER NOT NULL,
    "planId"          TEXT NOT NULL,
    "duration"        TEXT NOT NULL DEFAULT 'MONTHLY',
    "pricePerUnit"    DECIMAL(10,2) NOT NULL,
    "subtotal"        DECIMAL(10,2) NOT NULL,
    "discountPercent" DECIMAL(5,2)  NOT NULL DEFAULT 0,
    "discountAmount"  DECIMAL(10,2) NOT NULL DEFAULT 0,
    "totalAmount"     DECIMAL(10,2) NOT NULL,
    "requirements"    JSONB,
    "notes"           TEXT,
    "status"          "EstimateStatus" NOT NULL DEFAULT 'DRAFT',
    "closeReason"     TEXT,
    "sentAt"          TIMESTAMP(3),
    "acceptedAt"      TIMESTAMP(3),
    "linkedSocietyId" TEXT,
    "createdById"     TEXT,
    "createdAt"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "estimates_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "estimates_estimateNumber_key" ON "estimates"("estimateNumber");
CREATE INDEX "estimates_status_idx"           ON "estimates"("status");
CREATE INDEX "estimates_linkedSocietyId_idx"  ON "estimates"("linkedSocietyId");

ALTER TABLE "estimates" ADD CONSTRAINT "estimates_planId_fkey"
    FOREIGN KEY ("planId") REFERENCES "plans"("id") ON UPDATE CASCADE;
