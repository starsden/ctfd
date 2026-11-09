#!/usr/bin/env bash
# ==============================================================================
# verify-offline.sh - Проверка готовности сервера к работе без интернета
# ==============================================================================
set -uo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "===================================================="
echo -e "   Диагностика CTF-сервера (mvsosh Health Check)   "
echo -e "===================================================="

ERRORS=0

test_check() {
    local desc="$1"
    local cmd="$2"
    echo -n "[..] $desc: "
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        ERRORS=$((ERRORS + 1))
    fi
}

# 1. IP адрес
test_check "IP-адрес 192.168.100.1 настроен" "ip -4 addr show | grep -q '192.168.100.1'"

# 2. dnsmasq сервис
test_check "Служба dnsmasq запущена" "systemctl is-active --quiet dnsmasq"
test_check "dnsmasq слушает DNS (порт 53)" "ss -tlnup | grep -q ':53 '"
test_check "dnsmasq слушает DHCP (порт 67)" "ss -ulpn | grep -q ':67 '"
test_check "DNS резолвит mvsosh.local -> 192.168.100.1" "getent hosts mvsosh.local | grep -q '192.168.100.1' || nslookup mvsosh.local 127.0.0.1 2>/dev/null | grep -q '192.168.100.1'"

# 3. Docker и Swarm
test_check "Служба docker запущена" "systemctl is-active --quiet docker"
test_check "Docker Swarm активен" "docker info 2>/dev/null | grep -q 'Swarm: active'"
test_check "Overlay сеть ctfd-compose_frp_containers присутствует" "docker network inspect ctfd-compose_frp_containers"
test_check "Нода Swarm имеет метку name=linux-1" "docker node inspect $(docker node ls -q | head -n 1) 2>/dev/null | grep -q 'name=linux-1' || docker node inspect $(docker node ls -q | head -n 1) 2>/dev/null | grep -q '\"name\": \"linux-1\"'"


# 4. Образы Docker в локальном кэше
test_check "Образ ctfd-whale-local в локальном кэше" "docker image inspect ctfd-whale-local"
test_check "Образ local-frp в локальном кэше" "docker image inspect local-frp"
test_check "Образ mariadb:11 в локальном кэше" "docker image inspect mariadb:11"
test_check "Образ redis:7 в локальном кэше" "docker image inspect redis:7"
test_check "Образ тестового задания в локальном кэше" "docker image inspect mvsosh/test-web:latest >/dev/null 2>&1 || docker image inspect ctf/test-web:latest >/dev/null 2>&1 || docker image inspect test-web >/dev/null 2>&1"



# 5. Статус контейнеров compose
test_check "Контейнер ctfd запущен" "docker ps | grep -q 'ctfd'"
test_check "Контейнер db запущен и healthy" "docker ps --filter 'name=db' --filter 'health=healthy' -q | grep -q ."
test_check "Контейнер cache запущен" "docker ps | grep -q 'cache'"
test_check "Контейнер frps запущен" "docker ps | grep -q 'frps'"
test_check "Контейнер frpc запущен" "docker ps | grep -q 'frpc'"

# 6. HTTP доступность CTFd
test_check "CTFd отвечает по HTTP (порт 80 или 8000)" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000 2>/dev/null | grep -E -q '200|302' || curl -s -o /dev/null -w '%{http_code}' http://192.168.100.1:8000 2>/dev/null | grep -E -q '200|302' || curl -s -o /dev/null -w '%{http_code}' http://192.168.100.1 2>/dev/null | grep -E -q '200|302'"

echo -e "\n===================================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}[+] ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО! Сервер готов к соревнованиям.${NC}"
    echo -e "    Участники могут подключаться:"
    echo -e "    - Web URL:    ${BLUE}http://mvsosh.local:8000${NC} или ${BLUE}http://192.168.100.1:8000${NC}"
    echo -e "    - DHCP пул:   192.168.100.100 - 192.168.100.200"
    echo -e "    - Инстансы:   192.168.100.1:21000-22000"
else
    echo -e "${RED}[!] Обнаружено ошибок: $ERRORS. Проверьте детали выше.${NC}"
fi
echo -e "===================================================="
