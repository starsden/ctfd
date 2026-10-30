#!/usr/bin/env bash
# ==============================================================================
# export-offline-bundle.sh - Экспорт всех образов в tar-архив
# Используется для переноса на изолированный сервер через флешку / внешний диск
# ==============================================================================
set -euo pipefail

GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
NC='[0m'

OUTPUT_TAR="ctfd-offline-bundle.tar.gz"
echo -e "[*] Экспорт всех Docker-образов в $OUTPUT_TAR..."

IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v '<none>' | tr '
' ' ')

if [ -z "$IMAGES" ]; then
    echo "[!] Нет найденных Docker-образов для экспорта."
    exit 1
fi

echo -e "Сохраняются образы: $IMAGES"
docker save $IMAGES | gzip > "$OUTPUT_TAR"

echo -e "[+] Готово! Архив $OUTPUT_TAR успешно создан ($(du -h "$OUTPUT_TAR" | cut -f1))."
