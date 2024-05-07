-- CreateEnum
CREATE TYPE "Status" AS ENUM ('SENT', 'DELIVERED', 'READ');

-- CreateTable
CREATE TABLE "MessageStatus" (
    "id" UUID NOT NULL,
    "messageId" UUID NOT NULL,
    "status" "Status" NOT NULL DEFAULT 'SENT',

    CONSTRAINT "MessageStatus_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "MessageStatus" ADD CONSTRAINT "MessageStatus_messageId_fkey" FOREIGN KEY ("messageId") REFERENCES "PendingMessage"("id") ON DELETE CASCADE ON UPDATE CASCADE;
