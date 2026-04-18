ALTER TABLE "maintenance_bills"
ADD COLUMN "createdById" TEXT,
ADD COLUMN "deletedAt" TIMESTAMP(3),
ADD COLUMN "deletedById" TEXT;

CREATE TABLE "bill_audit_logs" (
    "id" TEXT NOT NULL,
    "billId" TEXT NOT NULL,
    "societyId" TEXT NOT NULL,
    "unitId" TEXT NOT NULL,
    "actorId" TEXT,
    "action" TEXT NOT NULL,
    "note" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "bill_audit_logs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "bill_audit_logs_billId_idx" ON "bill_audit_logs"("billId");
CREATE INDEX "bill_audit_logs_societyId_idx" ON "bill_audit_logs"("societyId");
CREATE INDEX "bill_audit_logs_unitId_idx" ON "bill_audit_logs"("unitId");

ALTER TABLE "maintenance_bills" ADD CONSTRAINT "maintenance_bills_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "maintenance_bills" ADD CONSTRAINT "maintenance_bills_deletedById_fkey" FOREIGN KEY ("deletedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "bill_audit_logs" ADD CONSTRAINT "bill_audit_logs_billId_fkey" FOREIGN KEY ("billId") REFERENCES "maintenance_bills"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "bill_audit_logs" ADD CONSTRAINT "bill_audit_logs_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
