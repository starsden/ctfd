#!/usr/bin/env bash
# ==============================================================================
# verify-offline.sh - Проверка готовности сервера к работе без интернета
# ==============================================================================
set -uo pipefail

RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
NC='[0m'

echo -e "===================================================="
echo -e "   Диагностика CTF-сервера (Offline Health Check)   "
echo -e "===================================================="

ERRORS=0

test_check() {
    local desc="$1"
    local cmd="$2"
    echo -n "[..] $desc: "
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "OK"
    else
        echo -e "FAIL"
        ERRORS=$((ERRORS + 1))
    fi
}

# 1. IP адрес
test_check "IP-адрес 192.168.100.1 настроен" "ip addr show | grep -q '192.168.100.1'"

# 2. dnsmasq сервис
test_check "Служба dnsmasq запущена" "systemctl is-active --quiet dnsmasq"
test_check "dnsmasq слушает DNS (порт 53/udp)" "ss -ulpn | grep -q ':53 '"
test_check "dnsmasq слушает DHCP (порт 67/udp)" "ss -ulpn | grep -q ':67 '"
test_check "DNS резолвит ctf.local -> 192.168.100.1" "getent hosts ctf.local | grep -q '192.168.100.1' || nslookup ctf.local 127.0.0.1 2>/dev/null | grep -q '192.168.100.1'"

# 3. Docker и Swarm
test_check "Служба docker запущена" "systemctl is-active --quiet docker"
test_check "Docker Swarm активен" "docker info 2>/dev/null | grep -q 'Swarm: active'"
test_check "Нода Swarm имеет метку name=linux-1" "docker node inspect $(docker node ls -q | head -n 1) | grep -q 'name=linux-1'"

# 4. Базовые Docker образы
test_check "Образ ctfd/ctfd в локальном кэше" "docker image inspect ctfd/ctfd:latest"
test_check "Образ mariadb:10.11 в локальном кэше" "docker image inspect mariadb:10.11"
test_check "Образ redis:7-alpine в локальном кэше" "docker image inspect redis:7-alpine"

# 5. Статус контейнеров CTFd
test_check "Контейнер ctfd запущен" "docker ps | grep -q 'ctfd'"
test_check "Контейнер db запущен" "docker ps | grep -q 'mariadb'"
test_check "Контейнер cache запущен" "docker ps | grep -q 'redis'"

# 6. HTTP доступность CTFd
test_check "CTFd отвечает по HTTP (192.168.100.1:80 или :8000)" "curl -s -o /dev/null -w '%{http_code}' http://192.168.100.1:8000 | grep -E -q '200|302' || curl -s -o /dev/null -w '%{http_code}' http://192.168.100.1 | grep -E -q '200|302'"

# 7. Тестовый запуск задания
test_check "Тестовый запуск контейнера задания (оффлайн)" "docker run --rm ctf/web-sample:latest echo 'Challenge container works offline'"

echo -e "
===================================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "[+] ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО! Сервер готов к соревнованиям."
    echo -e "    Участники могут подключаться:"
    echo -e "    - Web URL:    http://ctf.local или http://192.168.100.1"
    echo -e "    - DHCP пул:   192.168.100.50 - 192.168.100.200"
else
    echo -e "[!] Обнаружено ошибок: $ERRORS. Проверьте детали выше."
fi
echo -e "===================================================="
