/*
  Warnings:

  - Added the required column `senderId` to the `PendingMessage` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "PendingMessage" ADD COLUMN     "senderId" UUID NOT NULL;

-- AddForeignKey
ALTER TABLE "PendingMessage" ADD CONSTRAINT "PendingMessage_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
