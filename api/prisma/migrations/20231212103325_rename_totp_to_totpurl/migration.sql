/*
  Warnings:

  - You are about to drop the column `totp` on the `User` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "User" DROP COLUMN "totp",
ADD COLUMN     "totp_url" TEXT;
