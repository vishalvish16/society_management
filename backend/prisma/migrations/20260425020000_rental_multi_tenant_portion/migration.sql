-- AlterEnum: add PARTIALLY_RENTED to OccupancyType
ALTER TYPE "OccupancyType" ADD VALUE 'PARTIALLY_RENTED';

-- AlterTable: add portion field to rental_records
ALTER TABLE "rental_records" ADD COLUMN "portion" TEXT;
