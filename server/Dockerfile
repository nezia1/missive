FROM node:20-alpine as builder
WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma/

RUN npm install

COPY . .

FROM node:20-alpine
WORKDIR /app

# needed for wait-for-it.sh
RUN apk add --no-cache bash 

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/ .

RUN chmod +x ./wait-for-it.sh ./migrate-and-start.sh

EXPOSE 8080

ENTRYPOINT [ "./wait-for-it.sh", "db:5432", "--", "./migrate-and-start.sh"]
