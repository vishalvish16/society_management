-- Add audit trail fields to complaints and suggestions

ALTER TABLE "complaints"
  ADD COLUMN IF NOT EXISTS "updatedById" TEXT,
  ADD COLUMN IF NOT EXISTS "deletedById" TEXT;

ALTER TABLE "suggestions"
  ADD COLUMN IF NOT EXISTS "updatedById" TEXT,
  ADD COLUMN IF NOT EXISTS "deletedById" TEXT;

-- Foreign key constraints
ALTER TABLE "complaints"
  ADD CONSTRAINT "complaints_updatedById_fkey" FOREIGN KEY ("updatedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "complaints"
  ADD CONSTRAINT "complaints_deletedById_fkey" FOREIGN KEY ("deletedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "suggestions"
  ADD CONSTRAINT "suggestions_updatedById_fkey" FOREIGN KEY ("updatedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "suggestions"
  ADD CONSTRAINT "suggestions_deletedById_fkey" FOREIGN KEY ("deletedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
