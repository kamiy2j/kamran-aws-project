# Stage 1: Build dependencies  
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install --only=production && npm cache clean --force

# Stage 2: Runtime
FROM node:20-alpine AS production
WORKDIR /app
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node . .
USER node
EXPOSE 5000
CMD ["npm", "start"]