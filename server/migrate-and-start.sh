#!/bin/sh 
set -x
if [ "$NODE_ENV" = "production" ]; then
    npx prisma migrate deploy
    export COOKIE_SECRET=$(cat /run/secrets/cookie_secret)
    export PRIVATE_KEY_PATH=/run/secrets/private_key
    export PUBLIC_KEY_PATH=/run/secrets/public_key
    export GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/google_application_credentials
    npm start
else 
    echo "Running in development, migrating..."
    npx prisma migrate dev 
    npm run dev
fi

