#!/bin/sh 
set -x
if [ "$NODE_ENV" = "production" ]; then
    export DB_USER="$(cat /run/secrets/db_user)"
    export DB_PASSWORD="$(cat /run/secrets/db_password)"
    export DATABASE_URL="postgres://$DB_USER:$DB_PASSWORD@db:5432/missive"

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

