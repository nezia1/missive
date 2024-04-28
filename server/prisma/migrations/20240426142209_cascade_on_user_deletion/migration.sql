-- DropForeignKey
ALTER TABLE "PendingMessage" DROP CONSTRAINT "PendingMessage_senderId_fkey";

-- AddForeignKey
ALTER TABLE "PendingMessage" ADD CONSTRAINT "PendingMessage_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
