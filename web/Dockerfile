# syntax=docker/dockerfile:1

FROM node:22-slim AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
# Vite bakes this into the bundle, so it is a build arg, not a runtime env var.
ARG VITE_API_URL
RUN npm run build

FROM caddy:2-alpine
COPY Caddyfile /etc/caddy/Caddyfile
COPY --from=build /app/dist /srv
