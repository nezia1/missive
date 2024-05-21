#!/bin/sh 
if [ "$NODE_ENV" = "production" ]; then
    npx prisma migrate deploy
    npm start
else 
    npx prisma migrate dev 
    npm run dev
fi

