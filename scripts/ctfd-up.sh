#!/bin/bash
# /usr/local/bin/ctfd-up.sh — автоподъём стека CTFd после загрузки ОС.
set -euo pipefail

COMPOSE_DIR=/opt/mvsosh/CTFd-compose
NET_NAME=ctfd-compose_frp_containers
LOG=/var/log/ctfd-up.log

mkdir -p /var/log
exec >>"$LOG" 2>&1

echo "$(date -Is) starting ctfd-up.sh"

# Дожидаемся готовности docker daemon (до 60 секунд)
DOCKER_READY=0
for i in $(seq 1 30); do
    if docker info >/dev/null 2>&1; then
        DOCKER_READY=1
        break
    fi
    sleep 2
done

if [ "$DOCKER_READY" -ne 1 ]; then
    echo "$(date -Is) ERROR: Docker daemon is not responding."
    exit 1
fi

# Проверяем и инициализируем Docker Swarm при необходимости (требуется для overlay сети)
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo "$(date -Is) Swarm not active, initializing..."
    docker swarm leave --force 2>/dev/null || true
    docker swarm init --advertise-addr 192.168.100.1 --listen-addr 0.0.0.0:2377 2>/dev/null || \
    docker swarm init --advertise-addr 127.0.0.1 --listen-addr 0.0.0.0:2377 2>/dev/null || \
    docker swarm init 2>/dev/null || true
fi
NODE_ID=$(docker node ls -q 2>/dev/null | head -n 1 || true)
if [ -n "$NODE_ID" ]; then
    docker node update --label-add "name=linux-1" "$NODE_ID" >/dev/null 2>&1 || true
fi

# Гарантируем наличие overlay-сети инстансов (обычно живёт в raft swarm,
# но подстраховываемся)
if ! docker network inspect "$NET_NAME" >/dev/null 2>&1; then
    echo "$(date -Is) recreating network $NET_NAME"
    docker network create -d overlay --internal --attachable \
        --subnet 172.2.0.0/16 "$NET_NAME"
fi

if [ ! -d "$COMPOSE_DIR" ]; then
    echo "$(date -Is) ERROR: Directory $COMPOSE_DIR does not exist."
    exit 1
fi

cd "$COMPOSE_DIR"
if docker compose version >/dev/null 2>&1; then
    docker compose up -d
else
    docker-compose up -d
fi
echo "$(date -Is) compose up done"
