# Backend Dockerfile for Node.js
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY . .
USER node
EXPOSE 5000
CMD ["npm", "start"]