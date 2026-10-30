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

echo -e "===================================================="
echo -e "    Подготовка автономного CTFd сервера (Debian 13) "
echo -e "===================================================="

if [[ $EUID -ne 0 ]]; then
   echo -e "[!] Скрипт должен быть запущен с правами root (sudo)."
   exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATIC_IP="192.168.100.1"
SUBNET_MASK="255.255.255.0"

echo -e "
[1/7] Определение сетевого интерфейса..."
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo' | head -n 1 || echo "enp0s3")
echo -e "[+] Выбран интерфейс: $IFACE"

echo -e "
[2/7] Установка системных утилит и dnsmasq..."
apt-get update
apt-get install -y --no-install-recommends     curl     wget     git     jq     dnsmasq     dnsutils     iptables     ca-certificates

echo -e "
[3/7] Установка и проверка Docker и Docker Compose..."
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
echo -e "[+] Docker активен."

echo -e "
[4/7] Настройка статического IP и dnsmasq (DHCP + DNS)..."
# Настройка статического IP адреса на выбранном интерфейсе
ip addr add "${STATIC_IP}/24" dev "$IFACE" 2>/dev/null || true
ip link set dev "$IFACE" up

# Генерация конфига dnsmasq
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
echo -e "[+] dnsmasq настроен и запущен на $IFACE (IP: $STATIC_IP)."

echo -e "
[5/7] Инициализация Docker Swarm для плагина CTFd-Whale..."
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    docker swarm init --advertise-addr "$STATIC_IP" || docker swarm init
fi

NODE_ID=$(docker node ls -q | head -n 1)
docker node update --label-add "name=linux-1" "$NODE_ID"
echo -e "[+] Docker Swarm инициализирован. Нода $NODE_ID помечена как name=linux-1."

echo -e "
[6/7] Загрузка плагина CTFd-Whale..."
PLUGINS_DIR="$PROJECT_DIR/plugins"
mkdir -p "$PLUGINS_DIR"
if [ ! -d "$PLUGINS_DIR/ctfd-whale" ]; then
    echo -e "[*] Клонирование ctfd-whale..."
    git clone https://github.com/frankli0324/ctfd-whale.git "$PLUGINS_DIR/ctfd-whale" || {
        echo -e "[!] Клонирование из сети не удалось (возможно, уже оффлайн). Проверьте наличие каталога ctfd-whale."
    }
else
    echo -e "[+] Плагин ctfd-whale уже присутствует."
fi

echo -e "
[7/7] Настройка Systemd сервиса для автоматического старта CTFd..."
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
echo -e "[+] Сервис ctfd.service активирован."

echo -e "
===================================================="
echo -e "[+] Базовая настройка успешно завершена!             "
echo -e "    Для запуска сервисов выполните:                 "
echo -e "    systemctl start ctfd.service                    "
echo -e "===================================================="
