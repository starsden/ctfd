#!/usr/bin/env bash
# ==============================================================================
# setup-host.sh - Полная автоматическая настройка сервера CTFd на Debian 13
# ==============================================================================
set -euo pipefail

RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
NC='[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}    Подготовка автономного CTFd сервера (Debian 13) ${NC}"
echo -e "${BLUE}====================================================${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] Скрипт должен быть запущен с правами root (sudo).${NC}"
   exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATIC_IP="192.168.100.1"
SUBNET_MASK="255.255.255.0"

# Обеспечиваем права на исполнение для всех скриптов
chmod +x "$PROJECT_DIR"/scripts/*.sh
if [ -f "$PROJECT_DIR/challenges/web-sample/build.sh" ]; then
    chmod +x "$PROJECT_DIR/challenges/web-sample/build.sh"
fi

echo -e "
${YELLOW}[1/8] Определение сетевого интерфейса...${NC}"
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo' | head -n 1 || echo "enp0s3")
echo -e "${GREEN}[+] Выбран интерфейс: $IFACE${NC}"

echo -e "
${YELLOW}[2/8] Проверка и освобождение порта 80...${NC}"
for srv in apache2 nginx lighttpd; do
    if systemctl is-active --quiet "$srv" 2>/dev/null; then
        echo -e "[*] Обнаружен работающий веб-сервер $srv (занимает порт 80). Отключаем..."
        systemctl stop "$srv" 2>/dev/null || true
        systemctl disable "$srv" 2>/dev/null || true
    fi
done

echo -e "
${YELLOW}[3/8] Установка системных утилит и dnsmasq...${NC}"
apt-get update
apt-get install -y --no-install-recommends     curl     wget     git     jq     dnsmasq     dnsutils     iptables     ca-certificates     lsof

echo -e "
${YELLOW}[4/8] Установка и проверка Docker и Docker Compose...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "[*] Установка Docker CE..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo       "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian       bookworm stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

systemctl enable docker.service
systemctl start docker.service
echo -e "${GREEN}[+] Docker активен.${NC}"

echo -e "
${YELLOW}[5/8] Настройка статического IP и dnsmasq (DHCP + DNS)...${NC}"
ip addr add "${STATIC_IP}/24" dev "$IFACE" 2>/dev/null || true
ip link set dev "$IFACE" up

mkdir -p /etc/dnsmasq.d
cat <<EOF > /etc/dnsmasq.d/ctf.conf
interface=$IFACE
bind-interfaces
dhcp-range=192.168.100.50,192.168.100.200,255.255.255.0,12h
dhcp-option=3,192.168.100.1
dhcp-option=6,192.168.100.1
domain=local
expand-hosts
address=/ctf.local/192.168.100.1
address=/ctfd.local/192.168.100.1
address=/flag.box/192.168.100.1
no-resolv
log-dhcp
log-queries
log-facility=/var/log/dnsmasq.log
EOF

systemctl enable dnsmasq.service
systemctl restart dnsmasq.service
echo -e "${GREEN}[+] dnsmasq настроен и запущен на $IFACE (IP: $STATIC_IP).${NC}"

echo -e "
${YELLOW}[6/8] Инициализация Docker Swarm для плагина CTFd-Whale...${NC}"
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    docker swarm init --advertise-addr "$STATIC_IP" || docker swarm init
fi

NODE_ID=$(docker node ls -q | head -n 1)
docker node update --label-add "name=linux-1" "$NODE_ID"
echo -e "${GREEN}[+] Docker Swarm инициализирован. Нода $NODE_ID помечена как name=linux-1.${NC}"

echo -e "
${YELLOW}[7/8] Загрузка плагина CTFd-Whale...${NC}"
PLUGINS_DIR="$PROJECT_DIR/plugins"
mkdir -p "$PLUGINS_DIR"
if [ ! -d "$PLUGINS_DIR/ctfd-whale" ]; then
    echo -e "[*] Клонирование ctfd-whale..."
    git clone https://github.com/frankli0324/ctfd-whale.git "$PLUGINS_DIR/ctfd-whale" || {
        echo -e "${YELLOW}[!] Клонирование из сети не удалось (возможно, уже оффлайн). Проверьте наличие каталога ctfd-whale.${NC}"
    }
else
    echo -e "${GREEN}[+] Плагин ctfd-whale уже присутствует.${NC}"
fi

echo -e "
${YELLOW}[8/8] Настройка Systemd сервиса для автоматического старта CTFd...${NC}"
cat <<EOF > /etc/systemd/system/ctfd.service
[Unit]
Description=CTFd Platform with Docker Compose
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ctfd.service
echo -e "${GREEN}[+] Сервис ctfd.service активирован.${NC}"

echo -e "
${GREEN}====================================================${NC}"
echo -e "${GREEN}[+] Базовая настройка успешно завершена!             ${NC}"
echo -e "${GREEN}    Для запуска сервисов выполните:                 ${NC}"
echo -e "${GREEN}    systemctl start ctfd.service                    ${NC}"
echo -e "${GREEN}====================================================${NC}"
