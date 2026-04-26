-- CreateTable
CREATE TABLE "society_rules" (
    "id" TEXT NOT NULL,
    "societyId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "category" TEXT NOT NULL DEFAULT 'GENERAL',
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "society_rules_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "society_rules_societyId_isActive_idx" ON "society_rules"("societyId", "isActive");

-- CreateIndex
CREATE INDEX "society_rules_societyId_category_idx" ON "society_rules"("societyId", "category");

-- AddForeignKey
ALTER TABLE "society_rules" ADD CONSTRAINT "society_rules_societyId_fkey" FOREIGN KEY ("societyId") REFERENCES "societies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "society_rules" ADD CONSTRAINT "society_rules_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
