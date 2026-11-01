#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
docker build -t ctf/web-sample:latest "$DIR"
echo "[+] Образ ctf/web-sample:latest успешно собран."
