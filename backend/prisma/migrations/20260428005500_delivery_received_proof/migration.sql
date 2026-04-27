-- Add resident "received from watchman" proof fields for deliveries
ALTER TABLE "deliveries"
ADD COLUMN IF NOT EXISTS "collectedBy" TEXT,
ADD COLUMN IF NOT EXISTS "receivedAt" TIMESTAMP(3),
ADD COLUMN IF NOT EXISTS "receivedBy" TEXT,
ADD COLUMN IF NOT EXISTS "receivedPhotoUrl" TEXT;

