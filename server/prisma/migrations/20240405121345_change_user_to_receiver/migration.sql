/*
  Warnings:

  - You are about to drop the column `userId` on the `PendingMessage` table. All the data in the column will be lost.
  - Added the required column `receiverId` to the `PendingMessage` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE "PendingMessage" DROP CONSTRAINT "PendingMessage_userId_fkey";

-- AlterTable
ALTER TABLE "PendingMessage" DROP COLUMN "userId",
ADD COLUMN     "receiverId" UUID NOT NULL;

-- AddForeignKey
ALTER TABLE "PendingMessage" ADD CONSTRAINT "PendingMessage_receiverId_fkey" FOREIGN KEY ("receiverId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
