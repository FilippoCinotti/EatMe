FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

FROM node:22-alpine AS runtime
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
WORKDIR /app
RUN addgroup -S eatme && adduser -S eatme -G eatme
COPY --from=build --chown=eatme:eatme /app/.next/standalone ./
COPY --from=build --chown=eatme:eatme /app/.next/static ./.next/static
USER eatme
EXPOSE 3000
CMD ["node", "server.js"]
