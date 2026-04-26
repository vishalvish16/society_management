/*
  Warnings:

  - The values [active,inactive,under_maintenance] on the enum `AmenityStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [present,absent,half_day,leave] on the enum `AttendanceStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [pending,partial,paid,overdue] on the enum `BillStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [monthly,quarterly,yearly] on the enum `BillingCycle` will be removed. If these variants are still used in the database, this will fail.
  - The values [pending,confirmed,cancelled,completed] on the enum `BookingStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [plumbing,electrical,lift,parking,cleaning,security,other] on the enum `ComplaintCategory` will be removed. If these variants are still used in the database, this will fail.
  - The values [open,assigned,in_progress,resolved,closed] on the enum `ComplaintStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [pending,allowed,denied,collected,left_at_gate] on the enum `DeliveryStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [active,suspended,removed] on the enum `DomesticHelpStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [maid,cook,driver,nurse,sweeper,gardener,other] on the enum `DomesticHelpType` will be removed. If these variants are still used in the database, this will fail.
  - The values [pending,approved,rejected] on the enum `ExpenseStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [active,used,expired,cancelled] on the enum `GatePassStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [pending,dues_cleared,approved,rejected,completed] on the enum `MoveRequestStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [move_in,move_out] on the enum `MoveRequestType` will be removed. If these variants are still used in the database, this will fail.
  - The values [unit,role,all] on the enum `NotificationTargetType` will be removed. If these variants are still used in the database, this will fail.
  - The values [bill,payment,expense,visitor,announcement,manual,complaint,delivery,domestic_help,move_in_out,amenity,gate_pass] on the enum `NotificationType` will be removed. If these variants are still used in the database, this will fail.
  - The values [owner,tenant] on the enum `ResidentType` will be removed. If these variants are still used in the database, this will fail.
  - The values [valid,invalid,expired] on the enum `ScanResult` will be removed. If these variants are still used in the database, this will fail.
  - The values [active,suspended,deleted] on the enum `SocietyStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [trial,active,expired,cancelled] on the enum `SubscriptionStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [occupied,vacant,renovation] on the enum `UnitStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [car,two_wheeler,cycle,other] on the enum `VehicleType` will be removed. If these variants are still used in the database, this will fail.
  - The values [pending,valid,used,expired] on the enum `VisitorStatus` will be removed. If these variants are still used in the database, this will fail.
  - You are about to drop the column `razorpayOrderId` on the `amenity_bookings` table. All the data in the column will be lost.
  - You are about to drop the column `unitId` on the `parking_slots` table. All the data in the column will be lost.
  - You are about to drop the column `maxSecretaries` on the `plans` table. All the data in the column will be lost.
  - A unique constraint covering the columns `[userId]` on the table `staff` will be added. If there are existing duplicate values, this will fail.
  - Changed the type of `type` on the `parking_slots` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.
  - Changed the type of `name` on the `plans` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.

*/
-- CreateEnum
CREATE TYPE "ParkingSlotType" AS ENUM ('COVERED', 'OPEN', 'BASEMENT', 'VISITOR', 'STILT', 'RESERVED');

-- CreateEnum
CREATE TYPE "ParkingSlotStatus" AS ENUM ('AVAILABLE', 'OCCUPIED', 'RESERVED', 'UNDER_MAINTENANCE', 'BLOCKED');

-- CreateEnum
CREATE TYPE "ParkingAllotmentStatus" AS ENUM ('ACTIVE', 'RELEASED', 'TRANSFERRED', 'SUSPENDED');

-- CreateEnum
CREATE TYPE "ParkingChargeFrequency" AS ENUM ('MONTHLY', 'QUARTERLY', 'YEARLY', 'ONE_TIME');

-- CreateEnum
CREATE TYPE "ParkingSessionStatus" AS ENUM ('ACTIVE', 'COMPLETED', 'OVERSTAYED');

-- CreateEnum
CREATE TYPE "AmenityBookingType" AS ENUM ('FREE', 'SLOT', 'HALF_DAY', 'MONTHLY');

-- CreateEnum
CREATE TYPE "PollStatus" AS ENUM ('OPEN', 'CLOSED');

-- AlterEnum
BEGIN;
CREATE TYPE "AmenityStatus_new" AS ENUM ('ACTIVE', 'INACTIVE', 'UNDER_MAINTENANCE');
ALTER TABLE "amenities" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "amenities" ALTER COLUMN "status" TYPE "AmenityStatus_new" USING ("status"::text::"AmenityStatus_new");
ALTER TYPE "AmenityStatus" RENAME TO "AmenityStatus_old";
ALTER TYPE "AmenityStatus_new" RENAME TO "AmenityStatus";
DROP TYPE "AmenityStatus_old";
ALTER TABLE "amenities" ALTER COLUMN "status" SET DEFAULT 'ACTIVE';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "AttendanceStatus_new" AS ENUM ('PRESENT', 'ABSENT', 'HALF_DAY', 'LEAVE');
ALTER TABLE "staff_attendance" ALTER COLUMN "status" TYPE "AttendanceStatus_new" USING ("status"::text::"AttendanceStatus_new");
ALTER TYPE "AttendanceStatus" RENAME TO "AttendanceStatus_old";
ALTER TYPE "AttendanceStatus_new" RENAME TO "AttendanceStatus";
DROP TYPE "AttendanceStatus_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "BillStatus_new" AS ENUM ('PENDING', 'PARTIAL', 'PAID', 'OVERDUE');
ALTER TABLE "maintenance_bills" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "maintenance_bills" ALTER COLUMN "status" TYPE "BillStatus_new" USING ("status"::text::"BillStatus_new");
ALTER TYPE "BillStatus" RENAME TO "BillStatus_old";
ALTER TYPE "BillStatus_new" RENAME TO "BillStatus";
DROP TYPE "BillStatus_old";
ALTER TABLE "maintenance_bills" ALTER COLUMN "status" SET DEFAULT 'PENDING';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "BillingCycle_new" AS ENUM ('MONTHLY', 'QUARTERLY', 'YEARLY');
ALTER TYPE "BillingCycle" RENAME TO "BillingCycle_old";
ALTER TYPE "BillingCycle_new" RENAME TO "BillingCycle";
DROP TYPE "BillingCycle_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "BookingStatus_new" AS ENUM ('PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED');
ALTER TABLE "amenity_bookings" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "amenity_bookings" ALTER COLUMN "status" TYPE "BookingStatus_new" USING ("status"::text::"BookingStatus_new");
ALTER TYPE "BookingStatus" RENAME TO "BookingStatus_old";
ALTER TYPE "BookingStatus_new" RENAME TO "BookingStatus";
DROP TYPE "BookingStatus_old";
ALTER TABLE "amenity_bookings" ALTER COLUMN "status" SET DEFAULT 'PENDING';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "ComplaintCategory_new" AS ENUM ('MAINTENANCE', 'SECURITY', 'CLEANLINESS', 'NOISE', 'PARKING', 'OTHER');
ALTER TABLE "complaints" ALTER COLUMN "category" TYPE "ComplaintCategory_new" USING ("category"::text::"ComplaintCategory_new");
ALTER TABLE "suggestions" ALTER COLUMN "category" TYPE "ComplaintCategory_new" USING ("category"::text::"ComplaintCategory_new");
ALTER TYPE "ComplaintCategory" RENAME TO "ComplaintCategory_old";
ALTER TYPE "ComplaintCategory_new" RENAME TO "ComplaintCategory";
DROP TYPE "ComplaintCategory_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "ComplaintStatus_new" AS ENUM ('OPEN', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED');
ALTER TABLE "complaints" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "suggestions" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "complaints" ALTER COLUMN "status" TYPE "ComplaintStatus_new" USING ("status"::text::"ComplaintStatus_new");
ALTER TABLE "suggestions" ALTER COLUMN "status" TYPE "ComplaintStatus_new" USING ("status"::text::"ComplaintStatus_new");
ALTER TYPE "ComplaintStatus" RENAME TO "ComplaintStatus_old";
ALTER TYPE "ComplaintStatus_new" RENAME TO "ComplaintStatus";
DROP TYPE "ComplaintStatus_old";
ALTER TABLE "complaints" ALTER COLUMN "status" SET DEFAULT 'OPEN';
ALTER TABLE "suggestions" ALTER COLUMN "status" SET DEFAULT 'OPEN';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "DeliveryStatus_new" AS ENUM ('PENDING', 'ALLOWED', 'DENIED', 'COLLECTED', 'RETURNED', 'LEFT_AT_GATE');
ALTER TABLE "deliveries" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "deliveries" ALTER COLUMN "status" TYPE "DeliveryStatus_new" USING ("status"::text::"DeliveryStatus_new");
ALTER TYPE "DeliveryStatus" RENAME TO "DeliveryStatus_old";
ALTER TYPE "DeliveryStatus_new" RENAME TO "DeliveryStatus";
DROP TYPE "DeliveryStatus_old";
ALTER TABLE "deliveries" ALTER COLUMN "status" SET DEFAULT 'PENDING';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "DomesticHelpStatus_new" AS ENUM ('ACTIVE', 'SUSPENDED', 'REMOVED');
ALTER TABLE "domestic_helps" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "domestic_helps" ALTER COLUMN "status" TYPE "DomesticHelpStatus_new" USING ("status"::text::"DomesticHelpStatus_new");
ALTER TYPE "DomesticHelpStatus" RENAME TO "DomesticHelpStatus_old";
ALTER TYPE "DomesticHelpStatus_new" RENAME TO "DomesticHelpStatus";
DROP TYPE "DomesticHelpStatus_old";
ALTER TABLE "domestic_helps" ALTER COLUMN "status" SET DEFAULT 'ACTIVE';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "DomesticHelpType_new" AS ENUM ('MAID', 'COOK', 'DRIVER', 'NURSE', 'SWEEPER', 'GARDENER', 'OTHER');
ALTER TABLE "domestic_helps" ALTER COLUMN "type" TYPE "DomesticHelpType_new" USING ("type"::text::"DomesticHelpType_new");
ALTER TYPE "DomesticHelpType" RENAME TO "DomesticHelpType_old";
ALTER TYPE "DomesticHelpType_new" RENAME TO "DomesticHelpType";
DROP TYPE "DomesticHelpType_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "ExpenseStatus_new" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
ALTER TABLE "expenses" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "expenses" ALTER COLUMN "status" TYPE "ExpenseStatus_new" USING ("status"::text::"ExpenseStatus_new");
ALTER TYPE "ExpenseStatus" RENAME TO "ExpenseStatus_old";
ALTER TYPE "ExpenseStatus_new" RENAME TO "ExpenseStatus";
DROP TYPE "ExpenseStatus_old";
ALTER TABLE "expenses" ALTER COLUMN "status" SET DEFAULT 'PENDING';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "GatePassStatus_new" AS ENUM ('ACTIVE', 'USED', 'EXPIRED', 'CANCELLED');
ALTER TABLE "gate_passes" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "gate_passes" ALTER COLUMN "status" TYPE "GatePassStatus_new" USING ("status"::text::"GatePassStatus_new");
ALTER TYPE "GatePassStatus" RENAME TO "GatePassStatus_old";
ALTER TYPE "GatePassStatus_new" RENAME TO "GatePassStatus";
DROP TYPE "GatePassStatus_old";
ALTER TABLE "gate_passes" ALTER COLUMN "status" SET DEFAULT 'ACTIVE';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "MoveRequestStatus_new" AS ENUM ('PENDING', 'DUES_CLEARED', 'APPROVED', 'REJECTED', 'COMPLETED');
ALTER TABLE "move_requests" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "move_requests" ALTER COLUMN "status" TYPE "MoveRequestStatus_new" USING ("status"::text::"MoveRequestStatus_new");
ALTER TYPE "MoveRequestStatus" RENAME TO "MoveRequestStatus_old";
ALTER TYPE "MoveRequestStatus_new" RENAME TO "MoveRequestStatus";
DROP TYPE "MoveRequestStatus_old";
ALTER TABLE "move_requests" ALTER COLUMN "status" SET DEFAULT 'PENDING';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "MoveRequestType_new" AS ENUM ('MOVE_IN', 'MOVE_OUT');
ALTER TABLE "move_requests" ALTER COLUMN "type" TYPE "MoveRequestType_new" USING ("type"::text::"MoveRequestType_new");
ALTER TYPE "MoveRequestType" RENAME TO "MoveRequestType_old";
ALTER TYPE "MoveRequestType_new" RENAME TO "MoveRequestType";
DROP TYPE "MoveRequestType_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "NotificationTargetType_new" AS ENUM ('UNIT', 'ROLE', 'ALL');
ALTER TYPE "NotificationTargetType" RENAME TO "NotificationTargetType_old";
ALTER TYPE "NotificationTargetType_new" RENAME TO "NotificationTargetType";
DROP TYPE "NotificationTargetType_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "NotificationType_new" AS ENUM ('BILL', 'PAYMENT', 'EXPENSE', 'VISITOR', 'ANNOUNCEMENT', 'MANUAL', 'COMPLAINT', 'SUGGESTION', 'DELIVERY', 'DOMESTIC_HELP', 'MOVE_IN_OUT', 'AMENITY', 'GATE_PASS', 'PARKING');
ALTER TABLE "notifications" ALTER COLUMN "type" TYPE "NotificationType_new" USING ("type"::text::"NotificationType_new");
ALTER TYPE "NotificationType" RENAME TO "NotificationType_old";
ALTER TYPE "NotificationType_new" RENAME TO "NotificationType";
DROP TYPE "NotificationType_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "ResidentType_new" AS ENUM ('OWNER', 'TENANT');
ALTER TABLE "move_requests" ALTER COLUMN "residentType" DROP DEFAULT;
ALTER TABLE "move_requests" ALTER COLUMN "residentType" TYPE "ResidentType_new" USING ("residentType"::text::"ResidentType_new");
ALTER TYPE "ResidentType" RENAME TO "ResidentType_old";
ALTER TYPE "ResidentType_new" RENAME TO "ResidentType";
DROP TYPE "ResidentType_old";
ALTER TABLE "move_requests" ALTER COLUMN "residentType" SET DEFAULT 'TENANT';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "ScanResult_new" AS ENUM ('VALID', 'INVALID', 'EXPIRED');
ALTER TABLE "visitor_logs" ALTER COLUMN "scanResult" TYPE "ScanResult_new" USING ("scanResult"::text::"ScanResult_new");
ALTER TYPE "ScanResult" RENAME TO "ScanResult_old";
ALTER TYPE "ScanResult_new" RENAME TO "ScanResult";
DROP TYPE "ScanResult_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "SocietyStatus_new" AS ENUM ('ACTIVE', 'SUSPENDED', 'DELETED');
ALTER TABLE "societies" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "societies" ALTER COLUMN "status" TYPE "SocietyStatus_new" USING ("status"::text::"SocietyStatus_new");
ALTER TYPE "SocietyStatus" RENAME TO "SocietyStatus_old";
ALTER TYPE "SocietyStatus_new" RENAME TO "SocietyStatus";
DROP TYPE "SocietyStatus_old";
ALTER TABLE "societies" ALTER COLUMN "status" SET DEFAULT 'ACTIVE';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "SubscriptionStatus_new" AS ENUM ('TRIAL', 'ACTIVE', 'EXPIRED', 'CANCELLED');
ALTER TYPE "SubscriptionStatus" RENAME TO "SubscriptionStatus_old";
ALTER TYPE "SubscriptionStatus_new" RENAME TO "SubscriptionStatus";
DROP TYPE "SubscriptionStatus_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "UnitStatus_new" AS ENUM ('OCCUPIED', 'VACANT', 'RENOVATION');
ALTER TABLE "units" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "units" ALTER COLUMN "status" TYPE "UnitStatus_new" USING ("status"::text::"UnitStatus_new");
ALTER TYPE "UnitStatus" RENAME TO "UnitStatus_old";
ALTER TYPE "UnitStatus_new" RENAME TO "UnitStatus";
DROP TYPE "UnitStatus_old";
ALTER TABLE "units" ALTER COLUMN "status" SET DEFAULT 'OCCUPIED';
COMMIT;

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "UserRole" ADD VALUE 'CHAIRMAN';
ALTER TYPE "UserRole" ADD VALUE 'VICE_CHAIRMAN';
ALTER TYPE "UserRole" ADD VALUE 'ASSISTANT_SECRETARY';
ALTER TYPE "UserRole" ADD VALUE 'TREASURER';
ALTER TYPE "UserRole" ADD VALUE 'ASSISTANT_TREASURER';
ALTER TYPE "UserRole" ADD VALUE 'MEMBER';

-- AlterEnum
BEGIN;
CREATE TYPE "VehicleType_new" AS ENUM ('CAR', 'TWO_WHEELER', 'CYCLE', 'OTHER');
ALTER TABLE "vehicles" ALTER COLUMN "type" TYPE "VehicleType_new" USING ("type"::text::"VehicleType_new");
ALTER TYPE "VehicleType" RENAME TO "VehicleType_old";
ALTER TYPE "VehicleType_new" RENAME TO "VehicleType";
DROP TYPE "VehicleType_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "VisitorStatus_new" AS ENUM ('PENDING', 'VALID', 'USED', 'EXPIRED');
ALTER TABLE "visitors" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "visitors" ALTER COLUMN "status" TYPE "VisitorStatus_new" USING ("status"::text::"VisitorStatus_new");
ALTER TYPE "VisitorStatus" RENAME TO "VisitorStatus_old";
ALTER TYPE "VisitorStatus_new" RENAME TO "VisitorStatus";
DROP TYPE "VisitorStatus_old";
ALTER TABLE "visitors" ALTER COLUMN "status" SET DEFAULT 'PENDING';
COMMIT;

-- DropForeignKey
ALTER TABLE "parking_slots" DROP CONSTRAINT "parking_slots_unitId_fkey";

-- DropIndex
DROP INDEX "amenity_bookings_amenityId_bookingDate_startTime_key";

-- DropIndex
DROP INDEX "parking_slots_societyId_idx";

-- AlterTable
ALTER TABLE "amenities" ADD COLUMN     "bookingType" "AmenityBookingType" NOT NULL DEFAULT 'SLOT',
ADD COLUMN     "firstHalfEnd" TEXT,
ADD COLUMN     "fullDayFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN     "halfDayFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN     "maxDailyHours" INTEGER,
ADD COLUMN     "monthlyFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
ALTER COLUMN "openTime" SET DEFAULT '06:00',
ALTER COLUMN "closeTime" SET DEFAULT '22:00',
ALTER COLUMN "maxAdvanceDays" SET DEFAULT 30,
ALTER COLUMN "status" SET DEFAULT 'ACTIVE';

-- AlterTable
ALTER TABLE "amenity_bookings" DROP COLUMN "razorpayOrderId",
ADD COLUMN     "dailyHoursLimit" INTEGER,
ADD COLUMN     "halfDaySlot" TEXT,
ADD COLUMN     "monthYear" TEXT,
ALTER COLUMN "bookingDate" DROP NOT NULL,
ALTER COLUMN "startTime" DROP NOT NULL,
ALTER COLUMN "endTime" DROP NOT NULL,
ALTER COLUMN "status" SET DEFAULT 'PENDING';

-- AlterTable
ALTER TABLE "complaints" ADD COLUMN     "amount" DECIMAL(10,2) DEFAULT 0,
ADD COLUMN     "paidAmount" DECIMAL(10,2) DEFAULT 0,
ADD COLUMN     "paidAt" TIMESTAMP(3),
ADD COLUMN     "paymentMethod" TEXT,
ADD COLUMN     "paymentStatus" TEXT DEFAULT 'UNPAID',
ADD COLUMN     "priority" TEXT DEFAULT 'medium',
ADD COLUMN     "resolutionNote" TEXT,
ADD COLUMN     "transactionId" TEXT,
ALTER COLUMN "status" SET DEFAULT 'OPEN';

-- AlterTable
ALTER TABLE "deliveries" ADD COLUMN     "returnedAt" TIMESTAMP(3),
ALTER COLUMN "status" SET DEFAULT 'PENDING';

-- AlterTable
ALTER TABLE "domestic_helps" ALTER COLUMN "status" SET DEFAULT 'ACTIVE';

-- AlterTable
ALTER TABLE "expenses" ALTER COLUMN "status" SET DEFAULT 'PENDING';

-- AlterTable
ALTER TABLE "gate_passes" ALTER COLUMN "status" SET DEFAULT 'ACTIVE';

-- AlterTable
ALTER TABLE "maintenance_bills" ADD COLUMN     "category" TEXT NOT NULL DEFAULT 'MAINTENANCE',
ADD COLUMN     "description" TEXT,
ADD COLUMN     "title" TEXT,
ALTER COLUMN "status" SET DEFAULT 'PENDING';

-- AlterTable
ALTER TABLE "move_requests" ALTER COLUMN "status" SET DEFAULT 'PENDING',
ALTER COLUMN "residentType" SET DEFAULT 'TENANT';

-- AlterTable
ALTER TABLE "parking_slots" DROP COLUMN "unitId",
ADD COLUMN     "floor" INTEGER,
ADD COLUMN     "hasEVCharger" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "isHandicapped" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "length" DOUBLE PRECISION,
ADD COLUMN     "status" "ParkingSlotStatus" NOT NULL DEFAULT 'AVAILABLE',
ADD COLUMN     "width" DOUBLE PRECISION,
ADD COLUMN     "zone" TEXT,
DROP COLUMN "type",
ADD COLUMN     "type" "ParkingSlotType" NOT NULL;

-- AlterTable
ALTER TABLE "plans" DROP COLUMN "maxSecretaries",
ADD COLUMN     "maxUsers" INTEGER NOT NULL DEFAULT -1,
DROP COLUMN "name",
ADD COLUMN     "name" TEXT NOT NULL,
ALTER COLUMN "maxUnits" SET DEFAULT -1,
ALTER COLUMN "pricePerUnit" DROP DEFAULT;

-- AlterTable
ALTER TABLE "societies" ADD COLUMN     "planDuration" TEXT DEFAULT 'MONTHLY',
ALTER COLUMN "status" SET DEFAULT 'ACTIVE';

-- AlterTable
ALTER TABLE "staff" ADD COLUMN     "userId" TEXT;

-- AlterTable
ALTER TABLE "subscription_payments" ADD COLUMN     "duration" TEXT NOT NULL DEFAULT 'MONTHLY',
ADD COLUMN     "unitCount" INTEGER NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "suggestions" ALTER COLUMN "status" SET DEFAULT 'OPEN';

-- AlterTable
ALTER TABLE "units" ADD COLUMN     "advanceBalance" DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN     "deletedAt" TIMESTAMP(3),
ADD COLUMN     "maintenanceAmount" DECIMAL(10,2),
ALTER COLUMN "status" SET DEFAULT 'OCCUPIED';

-- AlterTable
ALTER TABLE "visitors" ADD COLUMN     "description" TEXT,
ADD COLUMN     "numberOfAdults" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN     "visitorEmail" TEXT,
ALTER COLUMN "status" SET DEFAULT 'PENDING';

-- DropEnum
DROP TYPE "PlanCode";

-- DropEnum
DROP TYPE "PlanName";

-- CreateTable
CREATE TABLE "donation_campaigns" (
    "id" TEXT NOT NULL,
    "societyId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "targetAmount" DECIMAL(10,2),
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3),
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "donation_campaigns_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "donations" (
    "id" TEXT NOT NULL,
    "societyId" TEXT NOT NULL,
    "campaignId" TEXT,
    "donorId" TEXT NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "paymentMethod" "PaymentMethod" NOT NULL,
    "note" TEXT,
    "paidAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "donations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "parking_allotments" (
    "id" TEXT NOT NULL,
    "societyId" TEXT NOT NULL,
    "slotId" TEXT NOT NULL,
    "unitId" TEXT NOT NULL,
    "vehicleId" TEXT,
    "allottedById" TEXT NOT NULL,
    "status" "ParkingAllotmentStatus" NOT NULL DEFAULT 'ACTIVE',
    "startDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endDate" TIMESTAMP(3),
    "previousAllotmentId" TEXT,
    "transferReason" TEXT,
    "releaseReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "parking_allotments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "parking_charges" (
    "id" TEXT NOT NULL,
    "societyId" TEXT NOT NULL,
    "slotId" TEXT NOT NULL,
    "allotmentId" TEXT,
    "unitId" TEXT NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "frequency" "ParkingChargeFrequency" NOT NULL,
    "dueDate" TIMESTAMP(3) NOT NULL,
    "paidAt" TIMESTAMP(3),
    "paymentMethod" "PaymentMethod",
    "isPaid" BOOLEAN NOT NULL DEFAULT false,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "parking_charges_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "parking_sessions" (
    "id" TEXT NOT NULL,
    "societyId" TEXT NOT NULL,
    "slotId" TEXT NOT NULL,
    "vehicleId" TEXT,
    "guestPlate" TEXT,
    "guestName" TEXT,
    "guestPhone" TEXT,
    "visitorId" TEXT,
    "deliveryId" TEXT,
    "linkedUnitId" TEXT,
    "entryAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "exitAt" TIMESTAMP(3),
    "expectedExitAt" TIMESTAMP(3),
    "entryById" TEXT NOT NULL,
    "exitById" TEXT,
    "status" "ParkingSessionStatus" NOT NULL DEFAULT 'ACTIVE',
    "notes" TEXT,

    CONSTRAINT "parking_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "maintenance_bill_schedules" (
    "id" TEXT NOT NULL,
    "societyId" TEXT NOT NULL,
    "billingMonth" TIMESTAMP(3) NOT NULL,
    "scheduledFor" TIMESTAMP(3) NOT NULL,
    "defaultAmount" DECIMAL(10,2) NOT NULL,
    "dueDate" TIMESTAMP(3) NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "lastRunAt" TIMESTAMP(3),
    "executedAt" TIMESTAMP(3),
    "createdById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "maintenance_bill_schedules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "complaint_attachments" (
    "id" TEXT NOT NULL,
    "complaintId" TEXT NOT NULL,
    "fileName" TEXT NOT NULL,
    "fileType" TEXT NOT NULL,
    "fileSize" INTEGER NOT NULL,
    "fileUrl" TEXT NOT NULL,
    "uploadedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "complaint_attachments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "polls" (
    "id" TEXT NOT NULL,
    "societyId" TEXT NOT NULL,
    "createdById" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "status" "PollStatus" NOT NULL DEFAULT 'OPEN',
    "allowMultiple" BOOLEAN NOT NULL DEFAULT false,
    "closesAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "polls_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "poll_options" (
    "id" TEXT NOT NULL,
    "pollId" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "poll_options_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "poll_recipients" (
    "id" TEXT NOT NULL,
    "pollId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "poll_recipients_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "poll_votes" (
    "id" TEXT NOT NULL,
    "pollId" TEXT NOT NULL,
    "optionId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "poll_votes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "platform_settings" (
    "key" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "dataType" TEXT NOT NULL DEFAULT 'number',
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "updatedBy" TEXT,

    CONSTRAINT "platform_settings_pkey" PRIMARY KEY ("key")
);

-- CreateIndex
CREATE INDEX "donation_campaigns_societyId_idx" ON "donation_campaigns"("societyId");

-- CreateIndex
CREATE INDEX "donations_societyId_idx" ON "donations"("societyId");

-- CreateIndex
CREATE INDEX "donations_campaignId_idx" ON "donations"("campaignId");

-- CreateIndex
CREATE INDEX "parking_allotments_societyId_status_idx" ON "parking_allotments"("societyId", "status");

-- CreateIndex
CREATE INDEX "parking_allotments_slotId_status_idx" ON "parking_allotments"("slotId", "status");

-- CreateIndex
CREATE INDEX "parking_allotments_unitId_idx" ON "parking_allotments"("unitId");

-- CreateIndex
CREATE INDEX "parking_allotments_vehicleId_idx" ON "parking_allotments"("vehicleId");

-- CreateIndex
CREATE INDEX "parking_charges_societyId_isPaid_idx" ON "parking_charges"("societyId", "isPaid");

-- CreateIndex
CREATE INDEX "parking_charges_unitId_idx" ON "parking_charges"("unitId");

-- CreateIndex
CREATE INDEX "parking_sessions_societyId_status_idx" ON "parking_sessions"("societyId", "status");

-- CreateIndex
CREATE INDEX "parking_sessions_slotId_status_idx" ON "parking_sessions"("slotId", "status");

-- CreateIndex
CREATE INDEX "maintenance_bill_schedules_societyId_isActive_idx" ON "maintenance_bill_schedules"("societyId", "isActive");

-- CreateIndex
CREATE INDEX "maintenance_bill_schedules_scheduledFor_idx" ON "maintenance_bill_schedules"("scheduledFor");

-- CreateIndex
CREATE UNIQUE INDEX "maintenance_bill_schedules_societyId_billingMonth_key" ON "maintenance_bill_schedules"("societyId", "billingMonth");

-- CreateIndex
CREATE INDEX "complaint_attachments_complaintId_idx" ON "complaint_attachments"("complaintId");

-- CreateIndex
CREATE INDEX "polls_societyId_status_idx" ON "polls"("societyId", "status");

-- CreateIndex
CREATE INDEX "polls_createdById_idx" ON "polls"("createdById");

-- CreateIndex
CREATE INDEX "poll_options_pollId_idx" ON "poll_options"("pollId");

-- CreateIndex
CREATE UNIQUE INDEX "poll_options_pollId_sortOrder_key" ON "poll_options"("pollId", "sortOrder");

-- CreateIndex
CREATE INDEX "poll_recipients_userId_idx" ON "poll_recipients"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "poll_recipients_pollId_userId_key" ON "poll_recipients"("pollId", "userId");

-- CreateIndex
CREATE INDEX "poll_votes_pollId_idx" ON "poll_votes"("pollId");

-- CreateIndex
CREATE INDEX "poll_votes_optionId_idx" ON "poll_votes"("optionId");

-- CreateIndex
CREATE INDEX "poll_votes_userId_idx" ON "poll_votes"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "poll_votes_pollId_userId_key" ON "poll_votes"("pollId", "userId");

-- CreateIndex
CREATE INDEX "amenity_bookings_amenityId_bookingDate_idx" ON "amenity_bookings"("amenityId", "bookingDate");

-- CreateIndex
CREATE INDEX "parking_slots_societyId_status_idx" ON "parking_slots"("societyId", "status");

-- CreateIndex
CREATE INDEX "parking_slots_societyId_type_idx" ON "parking_slots"("societyId", "type");

-- CreateIndex
CREATE UNIQUE INDEX "plans_name_key" ON "plans"("name");

-- CreateIndex
CREATE UNIQUE INDEX "staff_userId_key" ON "staff"("userId");

-- AddForeignKey
ALTER TABLE "donations" ADD CONSTRAINT "donations_societyId_fkey" FOREIGN KEY ("societyId") REFERENCES "societies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "donations" ADD CONSTRAINT "donations_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "donation_campaigns"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "donations" ADD CONSTRAINT "donations_donorId_fkey" FOREIGN KEY ("donorId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parking_allotments" ADD CONSTRAINT "parking_allotments_societyId_fkey" FOREIGN KEY ("societyId") REFERENCES "societies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parking_allotments" ADD CONSTRAINT "parking_allotments_slotId_fkey" FOREIGN KEY ("slotId") REFERENCES "parking_slots"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parking_allotments" ADD CONSTRAINT "parking_allotments_unitId_fkey" FOREIGN KEY ("unitId") REFERENCES "units"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parking_allotments" ADD CONSTRAINT "parking_allotments_vehicleId_fkey" FOREIGN KEY ("vehicleId") REFERENCES "vehicles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parking_charges" ADD CONSTRAINT "parking_charges_societyId_fkey" FOREIGN KEY ("societyId") REFERENCES "societies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parking_charges" ADD CONSTRAINT "parking_charges_slotId_fkey" FOREIGN KEY ("slotId") REFERENCES "parking_slots"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parking_charges" ADD CONSTRAINT "parking_charges_allotmentId_fkey" FOREIGN KEY ("allotmentId") REFERENCES "parking_allotments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parking_charges" ADD CONSTRAINT "parking_charges_unitId_fkey" FOREIGN KEY ("unitId") REFERENCES "units"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parking_sessions" ADD CONSTRAINT "parking_sessions_societyId_fkey" FOREIGN KEY ("societyId") REFERENCES "societies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parking_sessions" ADD CONSTRAINT "parking_sessions_slotId_fkey" FOREIGN KEY ("slotId") REFERENCES "parking_slots"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parking_sessions" ADD CONSTRAINT "parking_sessions_vehicleId_fkey" FOREIGN KEY ("vehicleId") REFERENCES "vehicles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parking_sessions" ADD CONSTRAINT "parking_sessions_linkedUnitId_fkey" FOREIGN KEY ("linkedUnitId") REFERENCES "units"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "amenity_bookings" ADD CONSTRAINT "amenity_bookings_bookedById_fkey" FOREIGN KEY ("bookedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "maintenance_bill_schedules" ADD CONSTRAINT "maintenance_bill_schedules_societyId_fkey" FOREIGN KEY ("societyId") REFERENCES "societies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "maintenance_bill_schedules" ADD CONSTRAINT "maintenance_bill_schedules_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "complaint_attachments" ADD CONSTRAINT "complaint_attachments_complaintId_fkey" FOREIGN KEY ("complaintId") REFERENCES "complaints"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff" ADD CONSTRAINT "staff_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscription_payments" ADD CONSTRAINT "subscription_payments_planId_fkey" FOREIGN KEY ("planId") REFERENCES "plans"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "polls" ADD CONSTRAINT "polls_societyId_fkey" FOREIGN KEY ("societyId") REFERENCES "societies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "polls" ADD CONSTRAINT "polls_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "poll_options" ADD CONSTRAINT "poll_options_pollId_fkey" FOREIGN KEY ("pollId") REFERENCES "polls"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "poll_recipients" ADD CONSTRAINT "poll_recipients_pollId_fkey" FOREIGN KEY ("pollId") REFERENCES "polls"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "poll_recipients" ADD CONSTRAINT "poll_recipients_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "poll_votes" ADD CONSTRAINT "poll_votes_pollId_fkey" FOREIGN KEY ("pollId") REFERENCES "polls"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "poll_votes" ADD CONSTRAINT "poll_votes_optionId_fkey" FOREIGN KEY ("optionId") REFERENCES "poll_options"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "poll_votes" ADD CONSTRAINT "poll_votes_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
