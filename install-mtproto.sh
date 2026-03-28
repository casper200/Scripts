cat > install-mtproto.sh << 'EOF'
#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "====================================="
echo "🚀 Установка MTProto прокси с Fake TLS"
echo "====================================="

# Функция установки Docker
install_docker() {
    echo ""
    echo -e "${YELLOW}📦 Docker не установлен. Начинаю установку...${NC}"
    
    # Обновляем систему
    sudo apt update -y
    
    # Устанавливаем зависимости
    sudo apt install -y ca-certificates curl gnupg
    
    # Добавляем ключ Docker
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Добавляем репозиторий Docker
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Устанавливаем Docker
    sudo apt update -y
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Добавляем пользователя в группу docker
    sudo usermod -aG docker $USER
    
    echo -e "${GREEN}✅ Docker успешно установлен!${NC}"
    echo -e "${YELLOW}⚠️  Для применения прав перезайдите в систему или выполните: newgrp docker${NC}"
    echo ""
    read -p "Нажмите Enter для продолжения..."
}

# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker не установлен${NC}"
    read -p "Установить Docker автоматически? (y/n): " INSTALL_DOCKER
    if [[ "$INSTALL_DOCKER" == "y" || "$INSTALL_DOCKER" == "Y" ]]; then
        install_docker
    else
        echo -e "${YELLOW}Установите Docker вручную:${NC}"
        echo "  curl -fsSL https://get.docker.com | sh"
        echo "  sudo usermod -aG docker \$USER"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Docker уже установлен${NC}"
fi

# Проверка Docker daemon
if ! sudo docker ps &> /dev/null; then
    echo -e "${RED}❌ Docker daemon не запущен${NC}"
    echo "Запускаю Docker..."
    sudo systemctl start docker
    sudo systemctl enable docker
    sleep 2
fi

# Настройки
echo ""
echo -e "${BLUE}📌 Настройки прокси:${NC}"
read -p "Порт (по умолчанию 443): " PORT
PORT=${PORT:-443}

read -p "Домен для маскировки (по умолчанию google.com): " FAKE_DOMAIN
FAKE_DOMAIN=${FAKE_DOMAIN:-google.com}

echo ""
echo -e "${BLUE}🔧 Генерация Fake TLS секрета...${NC}"

# Генерируем секрет
DOMAIN_HEX=$(printf '%s' "$FAKE_DOMAIN" | od -A n -t x1 | tr -d ' \n')
RANDOM_HEX=$(openssl rand -hex 15 | cut -c1-20)
SECRET="ee${DOMAIN_HEX}${RANDOM_HEX}"

echo -e "${GREEN}✅ Секрет сгенерирован${NC}"
echo -e "Первые 2 символа: ${YELLOW}${SECRET:0:2}${NC} (должны быть ee)"

# Проверка порта
echo ""
echo -n "🔍 Проверка порта $PORT... "
if ss -tuln | grep -q ":${PORT} "; then
    echo -e "${RED}занят${NC}"
    echo -e "${YELLOW}⚠️  Порт $PORT уже используется${NC}"
    read -p "Использовать другой порт? (y/n): " CHANGE_PORT
    if [[ "$CHANGE_PORT" == "y" ]]; then
        read -p "Введите новый порт: " PORT
        echo -e "${GREEN}✅ Будем использовать порт $PORT${NC}"
    else
        echo -e "${RED}❌ Невозможно продолжить, порт занят${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}свободен${NC}"
fi

# Останавливаем старый контейнер
echo ""
echo -n "🛑 Остановка старого контейнера... "
sudo docker stop mtproto-proxy 2>/dev/null
sudo docker rm mtproto-proxy 2>/dev/null
echo -e "${GREEN}готово${NC}"

# Запускаем новый контейнер
echo "📦 Запуск контейнера..."
sudo docker run -d \
    --name mtproto-proxy \
    --restart unless-stopped \
    -p ${PORT}:443 \
    -e SECRET=${SECRET} \
    seriyps/mtproto-proxy:latest

# Проверка запуска
sleep 3
echo ""

if sudo docker ps | grep -q mtproto-proxy; then
    # Получаем IP
    IP=$(curl -s ifconfig.me)
    if [ -z "$IP" ]; then
        IP=$(curl -s ipv4.icanhazip.com)
    fi
    if [ -z "$IP" ]; then
        IP=$(curl -s ipinfo.io/ip)
    fi
    if [ -z "$IP" ]; then
        IP=$(hostname -I | awk '{print $1}')
    fi
    
    echo -e "${GREEN}✅✅✅ ПРОКСИ УСПЕШНО ЗАПУЩЕН! ✅✅✅${NC}"
    echo ""
    echo "====================================="
    echo "📊 ПАРАМЕТРЫ ПОДКЛЮЧЕНИЯ:"
    echo "====================================="
    echo -e "🌐 Сервер: ${GREEN}$IP${NC}"
    echo -e "🔌 Порт: ${GREEN}$PORT${NC}"
    echo -e "🔑 Секрет: ${YELLOW}$SECRET${NC}"
    echo -e "🎭 Маскировка: ${BLUE}$FAKE_DOMAIN${NC}"
    echo "====================================="
    echo ""
    echo "🔗 ССЫЛКА ДЛЯ TELEGRAM (нажмите для подключения):"
    echo -e "${GREEN}tg://proxy?server=$IP&port=$PORT&secret=$SECRET${NC}"
    echo ""
    echo "====================================="
    echo "📋 ПОЛЕЗНЫЕ КОМАНДЫ:"
    echo "====================================="
    echo "Проверить статус:   sudo docker ps | grep mtproto-proxy"
    echo "Посмотреть логи:    sudo docker logs mtproto-proxy --tail 20"
    echo "Перезапустить:      sudo docker restart mtproto-proxy"
    echo "Остановить:         sudo docker stop mtproto-proxy"
    echo "Запустить:          sudo docker start mtproto-proxy"
    echo "====================================="
    
    # Сохраняем конфигурацию
    cat > ~/mtproxy-config.txt << EOF2
====================================
MTProto Proxy Configuration
====================================
Сервер: $IP
Порт: $PORT
Секрет: $SECRET
Домен маскировки: $FAKE_DOMAIN
Ссылка: tg://proxy?server=$IP&port=$PORT&secret=$SECRET
Дата установки: $(date)
====================================
EOF2
    echo ""
    echo -e "${GREEN}✅ Конфигурация сохранена в ~/mtproxy-config.txt${NC}"
    
    # Предупреждение о перезагрузке если Docker только что установлен
    if [[ "$INSTALL_DOCKER" == "y" ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  ВНИМАНИЕ: Docker был только что установлен${NC}"
        echo -e "${YELLOW}   Если команда docker требует sudo, выйдите и зайдите заново${NC}"
        echo -e "${YELLOW}   Или выполните: newgrp docker${NC}"
    fi
    
else
    echo -e "${RED}❌ ОШИБКА ЗАПУСКА${NC}"
    echo ""
    echo "Логи ошибки:"
    sudo docker logs mtproto-proxy
    exit 1
fi
EOF

# Делаем скрипт исполняемым
chmod +x install-mtproto.sh
