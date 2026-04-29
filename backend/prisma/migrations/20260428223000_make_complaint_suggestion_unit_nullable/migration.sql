-- Make unitId nullable for complaints & suggestions.
-- This prevents Prisma query failures when legacy rows have NULL unitId.

ALTER TABLE "complaints"
  ALTER COLUMN "unitId" DROP NOT NULL;

ALTER TABLE "suggestions"
  ALTER COLUMN "unitId" DROP NOT NULL;

