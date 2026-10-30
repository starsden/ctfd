#!/usr/bin/env bash
set -e
DIR=""
docker build -t ctf/web-sample:latest ""
echo "[+] Образ ctf/web-sample:latest успешно собран."
