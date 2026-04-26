-- CreateTable
CREATE TABLE "rental_members" (
    "id" TEXT NOT NULL,
    "rentalRecordId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "relation" TEXT NOT NULL,
    "age" INTEGER,
    "gender" TEXT,
    "phone" TEXT,
    "isAdult" BOOLEAN NOT NULL DEFAULT true,
    "aadhaarNumber" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "rental_members_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "rental_members_rentalRecordId_idx" ON "rental_members"("rentalRecordId");

-- AddForeignKey
ALTER TABLE "rental_members" ADD CONSTRAINT "rental_members_rentalRecordId_fkey" FOREIGN KEY ("rentalRecordId") REFERENCES "rental_records"("id") ON DELETE CASCADE ON UPDATE CASCADE;
