FROM node:20-alpine as builder
ARG DATABASE_URL
WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma/

RUN npm install

COPY . .

FROM node:20-alpine
ARG DATABASE_URL
WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/ .

EXPOSE 8080

ENTRYPOINT [ "./migrate-and-start.sh" ]
