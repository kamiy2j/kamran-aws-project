# Backend Dockerfile for Node.js
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --only=production && npm cache clean --force
COPY . .
USER node
EXPOSE 5000