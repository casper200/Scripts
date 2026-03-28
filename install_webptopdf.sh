##=====*webptopdf*=====##

sudo apt update -y

sudo apt install -y docker-ce docker-ce-cli docker-compose
sudo systemctl enable --now docker

docker --version
docker-compose --version

sudo systemctl status docker

#Настройка прав пользователя (чтобы не использовать sudo)
#Добавьте вашего пользователя в группу docker:
bash
sudo usermod -aG docker $USER

Установка Git
# или если Fedora с apt:
sudo apt install git -y


git clone https://github.com/EdwardMatthews/webptopdf.git

sudo usermod -aG docker vasa
groups vasa

##-----*Dockerfile*-------##
cat > Dockerfile << 'EOF'
FROM node:20-alpine AS base

# Устанавливаем системные зависимости для sharp
RUN apk add --no-cache \
    vips \
    vips-dev \
    fftw-dev \
    build-base \
    gcc \
    g++ \
    python3 \
    make

FROM base AS builder
WORKDIR /app

# Копируем package.json и устанавливаем зависимости
COPY package*.json ./
COPY yarn.lock* ./

# Устанавливаем зависимости (sharp установится через системные пакеты)
RUN npm ci

# Копируем исходный код
COPY . .

# Собираем приложение
RUN npm run build

FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production

# Создаем непривилегированного пользователя
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Копируем собранное приложение
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

# Копируем node_modules (включая sharp)
COPY --from=builder /app/node_modules ./node_modules

# Устанавливаем права
RUN chown -R nextjs:nodejs /app

# Переключаемся на непривилегированного пользователя
USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
EOF
##-----*Dockerfile*-------##

##-----*docker-compose.yml*-------##
cat > docker-compose.yml << 'EOF'
services:
  webp-to-pdf:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    restart: unless-stopped
EOF
docker-compose.yml
##-----*docker-compose.yml*-------##


# Собираем образ
docker compose build --no-cache

# Если сборка успешна, запускаем
docker compose up -d

# Смотрим логи в реальном времени
docker compose logs -f
