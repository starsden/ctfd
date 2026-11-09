#!/usr/bin/env bash
# ==============================================================================
# setup-host.sh - Автоматическая настройка сервера CTFd на Debian Trixie (mvsosh)
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}    Настройка автономного CTFd сервера (mvsosh)     ${NC}"
echo -e "${BLUE}====================================================${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] Скрипт должен быть запущен с правами root (sudo).${NC}"
   exit 1
fi

STATIC_IP="192.168.100.1"
SUBNET_MASK="255.255.255.0"
WORK_DIR="/opt/mvsosh/CTFd-compose"
STAGING_DIR="/opt/mvsosh/staging/CTFd"
FRP_STAGING_DIR="/opt/mvsosh/staging/frp"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "\n${YELLOW}[1/8] Определение сетевого интерфейса...${NC}"
if [ -n "${1:-}" ]; then
    IFACE="$1"
elif ip link show eth0 &>/dev/null; then
    IFACE="eth0"
elif ip link show enp0s8 &>/dev/null; then
    IFACE="enp0s8"
else
    IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v -E 'lo|docker|br-|veth' | head -n 1)
fi
echo -e "${GREEN}[+] Выбран интерфейс: $IFACE${NC}"

echo -e "\n${YELLOW}[2/8] Проверка и освобождение конфликтующих портов...${NC}"
for srv in apache2 nginx lighttpd; do
    if systemctl is-active --quiet "$srv" 2>/dev/null; then
        echo -e "[*] Отключение конфликтующей службы $srv..."
        systemctl stop "$srv" 2>/dev/null || true
        systemctl disable "$srv" 2>/dev/null || true
    fi
done

echo -e "\n${YELLOW}[3/8] Настройка статического IP и dnsmasq...${NC}"
mkdir -p /etc/network/interfaces.d
rm -f /etc/network/interfaces.d/ctf.cfg
cat <<EOF > /etc/network/interfaces.d/mvsosh-lab.cfg
auto $IFACE
iface $IFACE inet static
    address $STATIC_IP
    netmask $SUBNET_MASK
EOF

grep -q "interfaces.d" /etc/network/interfaces 2>/dev/null || echo "source /etc/network/interfaces.d/*" >> /etc/network/interfaces

ip addr replace "${STATIC_IP}/24" dev "$IFACE" 2>/dev/null || true
ip link set dev "$IFACE" up 2>/dev/null || true

# Конфигурация dnsmasq
mkdir -p /etc/dnsmasq.d
rm -f /etc/dnsmasq.d/ctf.conf /etc/dnsmasq.d/ctfd.conf /etc/dnsmasq.d/mvsosh.conf
cat <<EOF > /etc/dnsmasq.d/mvsosh-lab.conf
# ---- Слушаем только лабовый интерфейс ----
interface=$IFACE
bind-interfaces
listen-address=$STATIC_IP

# ---- DHCP ----
dhcp-range=192.168.100.100,192.168.100.200,255.255.255.0,12h
dhcp-option=option:router,$STATIC_IP
dhcp-option=option:dns-server,$STATIC_IP

# ---- DNS ----
local=/mvsosh.local/
domain=mvsosh.local
no-resolv
no-poll
address=/mvsosh.local/$STATIC_IP
address=/ctf.local/$STATIC_IP
address=/#/$STATIC_IP
EOF

systemctl enable --now dnsmasq
systemctl restart dnsmasq
echo -e "${GREEN}[+] Сеть и dnsmasq настроены.${NC}"

echo -e "\n${YELLOW}[4/8] Установка пакетов и настройка Docker...${NC}"
apt-get update
apt-get install -y --no-install-recommends \
    curl wget git jq dnsmasq dnsutils iptables ca-certificates lsof \
    docker.io

# Установка docker compose (в репозиториях Debian пакет называется docker-compose, в репозиториях Docker — docker-compose-plugin)
if ! apt-get install -y --no-install-recommends docker-compose 2>/dev/null; then
    apt-get install -y --no-install-recommends docker-compose-plugin 2>/dev/null || true
fi

# Обеспечиваем работу 'docker compose' (плагин)
if ! docker compose version >/dev/null 2>&1; then
    mkdir -p /usr/local/lib/docker/cli-plugins /usr/libexec/docker/cli-plugins
    if [ -f /usr/bin/docker-compose ]; then
        ln -sf /usr/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose 2>/dev/null || true
        ln -sf /usr/bin/docker-compose /usr/libexec/docker/cli-plugins/docker-compose 2>/dev/null || true
    fi
fi

systemctl enable docker containerd
systemctl start docker containerd

if [ -n "${SUDO_USER:-}" ]; then
    usermod -aG docker "$SUDO_USER" || true
fi

# Ожидание готовности Docker daemon
for i in $(seq 1 10); do
    if docker info >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

echo -e "\n${YELLOW}[5/8] Инициализация Docker Swarm...${NC}"
if ! docker info 2>/dev/null | grep -q 'Swarm: active'; then
    echo -e "[*] Инициализация Docker Swarm кластера..."
    docker swarm leave --force 2>/dev/null || true
    docker swarm init --advertise-addr "$STATIC_IP" --listen-addr 0.0.0.0:2377 2>/dev/null || \
    docker swarm init --advertise-addr 127.0.0.1 --listen-addr 0.0.0.0:2377 2>/dev/null || \
    docker swarm init 2>/dev/null || true
fi

NODE_ID=$(docker node ls -q 2>/dev/null | head -n 1 || true)
if [ -n "$NODE_ID" ]; then
    docker node update --label-add "name=linux-1" "$NODE_ID" >/dev/null 2>&1 || true
    echo -e "${GREEN}[+] Docker Swarm активен (нода $NODE_ID помечена как name=linux-1).${NC}"
else
    echo -e "${YELLOW}[!] Предупреждение: Swarm активен, но метку ноды не удалось выставить сразу.${NC}"
fi

echo -e "\n${YELLOW}[6/8] Создание структуры каталогов и копирование конфигураций...${NC}"
mkdir -p "$WORK_DIR/conf" "$WORK_DIR/uploads" "$STAGING_DIR/whale" "$STAGING_DIR/test-web" "$FRP_STAGING_DIR"

# Копирование docker-compose и конфигов
cp -f "$SCRIPT_DIR/docker-compose.yml" "$WORK_DIR/"
cp -rf "$SCRIPT_DIR/conf/"* "$WORK_DIR/conf/"

# Копирование staging файлов
cp -rf "$SCRIPT_DIR/staging/CTFd/"* "$STAGING_DIR/"
cp -rf "$SCRIPT_DIR/staging/frp/"* "$FRP_STAGING_DIR/"

echo -e "\n${YELLOW}[7/8] Сборка Docker-образов...${NC}"
# 1. CTFd с плагином whale
echo -e "[*] Сборка ctfd-whale-local..."
docker build -t ctfd-whale-local "$STAGING_DIR"

# 2. FRP image
echo -e "[*] Сборка local-frp..."
docker build -t local-frp "$FRP_STAGING_DIR"

# 3. Тестовое задание test-web (теги mvsosh/test-web:latest и ctf/test-web:latest)
echo -e "[*] Сборка test-web..."
docker build -t mvsosh/test-web:latest "$STAGING_DIR/test-web"
docker tag mvsosh/test-web:latest ctf/test-web:latest || true
docker tag mvsosh/test-web:latest test-web:latest || true

echo -e "${GREEN}[+] Все Docker-образы собраны.${NC}"

echo -e "\n${YELLOW}[8/8] Создание overlay-сети и запуск стека...${NC}"
NET_NAME="ctfd-compose_frp_containers"
if ! docker network inspect "$NET_NAME" >/dev/null 2>&1; then
    docker network create -d overlay --internal --attachable --subnet 172.2.0.0/16 "$NET_NAME"
fi

# Установка скрипта ctfd-up.sh
cp -f "$SCRIPT_DIR/scripts/ctfd-up.sh" /usr/local/bin/ctfd-up.sh
chmod +x /usr/local/bin/ctfd-up.sh

# Установка systemd service
cp -f "$SCRIPT_DIR/systemd/ctfd-compose.service" /etc/systemd/system/ctfd-compose.service
systemctl daemon-reload
systemctl enable ctfd-compose.service

echo -e "[*] Запуск стека через автоподъёмник..."
/usr/local/bin/ctfd-up.sh

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN}[+] Развертывание успешно завершено!${NC}"
echo -e "    CTFd доступен по адресам:"
echo -e "    -> http://mvsosh.local:8000"
echo -e "    -> http://192.168.100.1:8000"
echo -e "    Диапазон динамических портов: 21000-22000"
echo -e "${GREEN}====================================================${NC}"
