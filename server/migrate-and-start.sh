#!/bin/sh 
if [ "$NODE_ENV" = "production" ]; then
    export DATABASE_URL="postgresql://$(cat /run/secrets/db_user):$(cat /run/secrets/db_password)@db:5432/missive"
    echo "$DATABASE_URL"
    npx prisma migrate deploy
    export COOKIE_SECRET=$(cat /run/secrets/cookie_secret)
    export PRIVATE_KEY_PATH=/run/secrets/private_key
    export PUBLIC_KEY_PATH=/run/secrets/public_key
    export GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/google_application_credentials
    npm start
else 
    npx prisma migrate dev 
    npm run dev
fi

