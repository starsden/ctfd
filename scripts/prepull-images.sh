#!/usr/bin/env bash
# ==============================================================================
# prepull-images.sh - Скачивание всех образов для работы в оффлайн-режиме
# Запускается НА ЭТАПЕ, КОГДА ЕСТЬ ДОСТУП В ИНТЕРНЕТ.
# ==============================================================================
set -euo pipefail

GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
NC='[0m'

echo -e "===================================================="
echo -e "   Кэширование Docker-образов для оффлайн-работы   "
echo -e "===================================================="

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

echo -e "
[1/3] Загрузка базовых образов CTFd..."
for img in "${CORE_IMAGES[@]}"; do
    echo -e "[*] Скачивание $img..."
    docker pull "$img"
done

echo -e "
[2/3] Загрузка стандартных базовых образов для заданий..."
for img in "${BASE_CHALLENGE_IMAGES[@]}"; do
    echo -e "[*] Скачивание $img..."
    docker pull "$img"
done

echo -e "
[3/3] Сборка локальных образов заданий..."
if [ -f "$PROJECT_DIR/challenges/web-sample/build.sh" ]; then
    echo -e "[*] Сборка тестового задания ctf/web-sample:latest..."
    bash "$PROJECT_DIR/challenges/web-sample/build.sh"
fi

echo -e "
[+] Все необходимые образы успешно сохранены в локальный Docker daemon!"
echo -e "Список доступных локальных образов:"
docker images --format "table {{.Repository}}:{{.Tag}}	{{.Size}}"
