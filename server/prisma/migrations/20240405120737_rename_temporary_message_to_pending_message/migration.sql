/*
  Warnings:

  - You are about to drop the `TemporaryMessage` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "TemporaryMessage" DROP CONSTRAINT "TemporaryMessage_userId_fkey";

-- DropTable
DROP TABLE "TemporaryMessage";

-- CreateTable
CREATE TABLE "PendingMessage" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PendingMessage_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "PendingMessage" ADD CONSTRAINT "PendingMessage_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
