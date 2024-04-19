/*
  Warnings:

  - Added the required column `identityKey` to the `User` table without a default value. This is not possible if the table is not empty.
  - Added the required column `registrationId` to the `User` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "User" ADD COLUMN     "identityKey" TEXT NOT NULL,
ADD COLUMN     "registrationId" TEXT NOT NULL;
