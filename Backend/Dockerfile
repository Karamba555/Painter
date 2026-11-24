FROM node:24-bookworm-slim
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && mkdir -p /data && chown node:node /data
COPY src ./src
USER node
ENV HOST=0.0.0.0 PORT=8080 DATABASE_PATH=/data/trace-studio.sqlite
EXPOSE 8080
CMD ["node", "src/main.mjs"]
