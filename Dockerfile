# Use official Node base (Strapi recommends node:20-alpine or similar)
# New test run - 
FROM node:20-alpine

# Install dependencies needed for sharp (image processing)
RUN apk add --no-cache python3 make g++ libc6-compat

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

# Build admin panel
RUN npm run build

# Expose Strapi port
EXPOSE 1337

# Start Strapi in production mode
CMD ["npm", "run", "start"]
