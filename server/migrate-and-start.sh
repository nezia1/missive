#!/bin/sh 
if [ "$NODE_ENV" == "production" ]; then
    npx prisma migrate deploy
else 
    npx prisma migrate dev 
fi
npm start

