/*
  Warnings:

  - You are about to drop the column `playerID` on the `User` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "User" DROP COLUMN "playerID",
ADD COLUMN     "notificationID" TEXT;
