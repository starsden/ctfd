#!/usr/bin/env bash
# ==============================================================================
# import-offline-bundle.sh - Импорт Docker-образов из tar-архива на оффлайн-сервере
# ==============================================================================
set -euo pipefail

GREEN='[0;32m'
RED='[0;31m'
NC='[0m'

INPUT_TAR="${1:-ctfd-offline-bundle.tar.gz}"

if [ ! -f "$INPUT_TAR" ]; then
    echo -e "[!] Файл $INPUT_TAR не найден!"
    echo "Использование: $0 [путь_к_архиву.tar.gz]"
    exit 1
fi

echo -e "[*] Распаковка и импорт образов из $INPUT_TAR в Docker daemon..."
gzip -dc "$INPUT_TAR" | docker load

echo -e "[+] Образы успешно загружены в локальный Docker:"
docker images
