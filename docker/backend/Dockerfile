# ─── Stage 1: Builder ───
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install --production --no-optional && npm cache clean --force
COPY . .

# ─── Stage 2: Runtime ───
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app . 
USER node
EXPOSE 5000
CMD ["npm", "start"]