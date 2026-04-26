-- AlterTable
ALTER TABLE "suggestions"
ADD COLUMN     "amount" DECIMAL(10,2) DEFAULT 0,
ADD COLUMN     "paidAmount" DECIMAL(10,2) DEFAULT 0,
ADD COLUMN     "paymentMethod" TEXT,
ADD COLUMN     "paymentStatus" TEXT DEFAULT 'UNPAID',
ADD COLUMN     "transactionId" TEXT,
ADD COLUMN     "paidAt" TIMESTAMP(3);

