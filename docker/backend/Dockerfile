# Multi-stage build for Node.js backend
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./

# Use npm install instead of npm ci for development
RUN npm install --only=production

# Production stage
FROM node:20-alpine
WORKDIR /app

# Copy node_modules from builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY . .

EXPOSE 5000

USER node

CMD ["npm", "start"]