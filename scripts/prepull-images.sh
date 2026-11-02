#!/usr/bin/env bash
# ==============================================================================
# prepull-images.sh - Скачивание всех образов для работы в оффлайн-режиме
# Запускается НА ЭТАПЕ, КОГДА ЕСТЬ ДОСТУП В ИНТЕРНЕТ.
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}   Кэширование Docker-образов для оффлайн-работы   ${NC}"
echo -e "${BLUE}====================================================${NC}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CORE_IMAGES=(
    "ctfd/ctfd:latest"
    "mariadb:10.11"
    "redis:7-alpine"
)

BASE_CHALLENGE_IMAGES=(
    "php:8.2-apache"
    "python:3.11-slim"
    "ubuntu:22.04"
    "alpine:3.19"
)

echo -e "\n${YELLOW}[1/4] Загрузка базовых образов CTFd...${NC}"
for img in "${CORE_IMAGES[@]}"; do
    echo -e "[*] Скачивание $img..."
    docker pull "$img"
done

echo -e "\n${YELLOW}[2/4] Сборка образа CTFd с предустановленными зависимостями Whale...${NC}"
docker compose -f "$PROJECT_DIR/docker-compose.yml" build ctfd

echo -e "\n${YELLOW}[3/4] Загрузка стандартных базовых образов для заданий...${NC}"
for img in "${BASE_CHALLENGE_IMAGES[@]}"; do
    echo -e "[*] Скачивание $img..."
    docker pull "$img"
done

echo -e "\n${YELLOW}[4/4] Сборка локальных образов заданий...${NC}"
if [ -f "$PROJECT_DIR/challenges/web-sample/build.sh" ]; then
    echo -e "[*] Сборка тестового задания ctf/web-sample:latest..."
    bash "$PROJECT_DIR/challenges/web-sample/build.sh"
fi

echo -e "\n${GREEN}[+] Все необходимые образы успешно сохранены в локальный Docker daemon!${NC}"
echo -e "Список доступных локальных образов:"
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
