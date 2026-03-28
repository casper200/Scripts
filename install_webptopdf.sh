#!/usr/bin/env bash
##=====*webptopdf*=====##

sudo apt update -y

sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo systemctl enable --now docker

docker --version
docker compose version

sudo usermod -aG docker $USER

sudo apt install git -y

git clone https://github.com/EdwardMatthews/webptopdf.git
cd webptopdf

cat > Dockerfile << 'EOF'
FROM node:20-alpine
RUN apk add --no-cache vips vips-dev build-base gcc g++ python3 make
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "start"]
EOF

cat > docker-compose.yml << 'EOF'
services:
  webp-to-pdf:
    build: .
    ports:
      - "3000:3000"
    restart: unless-stopped
EOF

docker compose build --no-cache
docker compose up -d
docker compose logs -f
