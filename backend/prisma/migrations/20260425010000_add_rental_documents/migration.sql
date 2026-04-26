-- CreateTable
CREATE TABLE "rental_documents" (
    "id" TEXT NOT NULL,
    "rentalRecordId" TEXT NOT NULL,
    "docType" TEXT NOT NULL,
    "fileName" TEXT NOT NULL,
    "fileType" TEXT NOT NULL,
    "fileSize" INTEGER NOT NULL,
    "fileUrl" TEXT NOT NULL,
    "uploadedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "rental_documents_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "rental_documents_rentalRecordId_idx" ON "rental_documents"("rentalRecordId");

-- AddForeignKey
ALTER TABLE "rental_documents" ADD CONSTRAINT "rental_documents_rentalRecordId_fkey" FOREIGN KEY ("rentalRecordId") REFERENCES "rental_records"("id") ON DELETE CASCADE ON UPDATE CASCADE;
