-- User profile enrichment (photo, household, DOB, emergency contact)
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "profilePhotoUrl" TEXT;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "dateOfBirth" DATE;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "householdMemberCount" INTEGER;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "bio" TEXT;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "emergencyContactName" TEXT;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "emergencyContactPhone" TEXT;
