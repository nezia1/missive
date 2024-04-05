/*
  Warnings:

  - You are about to drop the column `createdAt` on the `PendingMessage` table. All the data in the column will be lost.
  - You are about to drop the column `updatedAt` on the `PendingMessage` table. All the data in the column will be lost.
  - Added the required column `content` to the `PendingMessage` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "PendingMessage" DROP COLUMN "createdAt",
DROP COLUMN "updatedAt",
ADD COLUMN     "content" TEXT NOT NULL,
ADD COLUMN     "sentAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
