-- Add edit/delete attribution to vehicles + create audit log table

ALTER TABLE "vehicles"
ADD COLUMN "updatedById" TEXT,
ADD COLUMN "removedAt" TIMESTAMP(3),
ADD COLUMN "removedById" TEXT;

CREATE TABLE "vehicle_audit_logs" (
    "id" TEXT NOT NULL,
    "vehicleId" TEXT NOT NULL,
    "societyId" TEXT NOT NULL,
    "unitId" TEXT NOT NULL,
    "actorId" TEXT,
    "action" TEXT NOT NULL,
    "note" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "vehicle_audit_logs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "vehicle_audit_logs_vehicleId_idx" ON "vehicle_audit_logs"("vehicleId");
CREATE INDEX "vehicle_audit_logs_societyId_idx" ON "vehicle_audit_logs"("societyId");
CREATE INDEX "vehicle_audit_logs_unitId_idx" ON "vehicle_audit_logs"("unitId");

ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_registeredById_fkey" FOREIGN KEY ("registeredById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_updatedById_fkey" FOREIGN KEY ("updatedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_removedById_fkey" FOREIGN KEY ("removedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "vehicle_audit_logs" ADD CONSTRAINT "vehicle_audit_logs_vehicleId_fkey" FOREIGN KEY ("vehicleId") REFERENCES "vehicles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "vehicle_audit_logs" ADD CONSTRAINT "vehicle_audit_logs_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

