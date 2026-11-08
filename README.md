# Автономный CTF-сервер для локальной сети без интернета (mvsosh)

Комплексное решение для проведения CTF-соревнований в закрытой локальной сети (offline environment):
- **Сервер:** Debian 13 (Trixie) в VirtualBox.
- **Платформа соревнований:** CTFd + MariaDB + Redis.
- **Динамические Docker-задания:** Плагин `ctfd-whale` (выдача персонального контейнера каждому участнику/команде с таймером и динамическим флагом).
- **Сетевая служба:** Лёгкий `dnsmasq` (DHCP + DNS `mvsosh.local`).
- **Участники:** Виртуальные машины Kali Linux в VirtualBox.
- **Автоматизация:** Полный автозапуск всех сервисов на старте ОС через systemd без ручного вмешательства.
- **Оффлайн-режим:** 100% автономная работа без необходимости внешнего интернета.

---

## Архитектура сети (VirtualBox)

Виртуальная машина Debian 13 настраивается со статическим адресом на интерфейсе лабы (`eth0` или `enp0s8`):
- **IP сервера:** `192.168.100.1 / 255.255.255.0`
- **DHCP пул участников:** `192.168.100.100` — `192.168.100.200`
- **CTFd веб-интерфейс:** `http://mvsosh.local:8000` (или `http://192.168.100.1:8000`)
- **Динамические порты заданий:** `192.168.100.1:21000-22000`

---

## Ответы на частые вопросы по сети и доменам

### 1. Прописывалось ли имя `ctf.local` в конфиге веб-сервера?
**Нет, веб-сервер CTFd (Gunicorn/Flask) не привязан к конкретному доменному имени.**
Он слушает сокет `0.0.0.0:8000` и принимает HTTP-запросы с **любым** заголовком `Host`. Никаких жестких ограничений по домену в коде или конфигах CTFd нет.

### 2. Почему новое имя пингуется, а в браузере не открывается или дает ошибку 500?
1. **Пинг успешен:** `ping` проверяет только ICMP/DNS резолв. `dnsmasq` отдает `192.168.100.1` на любое имя благодаря wildcard-записи `address=/#/192.168.100.1`, поэтому ping работает.
2. **Обязательно указывать порт `:8000`:** CTFd опубликован на порту `8000`. Если ввести в браузере просто `http://mvsosh.local`, браузер отправляет запрос на порт `80`. Нужно открывать строго `http://mvsosh.local:8000`.
3. **Причина ошибки 500 на первом запросе:**
   - **Сессионные куки и CSRF:** Если ранее в браузере открывался CTFd под другим именем (например, `ctf.local`), в браузере остались сессионные куки. При открытии под новым доменом защита Flask CSRF/Session вызывает несоответствие сессии и разовый сбой.
   - **Инициализация плагина ctfd-whale:** При самом первом HTTP-запросе к CTFd после старта плагин выполняет инициализацию таблиц и дефолтных настроек в базе данных (`setup_default_configs`). Если запрос попадает во время миграций воркеров, Flask возвращает HTTP 500 один раз, а после обновления страницы всё работает стабильно.

---

## Быстрый старт на сервере

```bash
# 1. Запуск комплексной настройки (Debian 13)
sudo bash ./scripts/setup-host.sh eth0

# 2. Проверка статуса сервисов
sudo bash ./scripts/verify-offline.sh
```

---

## Структура каталогов и компонентов

- [docker-compose.yml](file:///Users/den/Developer/ctfd/docker-compose.yml) — рабочий стек CTFd, MariaDB, Redis, frps и frpc.
- [WALKTHROUGH.md](file:///Users/den/Developer/ctfd/WALKTHROUGH.md) — подробная сводная инструкция администратора.
- [conf/frps.ini](file:///Users/den/Developer/ctfd/conf/frps.ini) — конфигурация сервера FRP (порты `21000-22000`).
- [conf/frpc.ini](file:///Users/den/Developer/ctfd/conf/frpc.ini) — конфигурация клиента FRP и Admin API (`0.0.0.0:7400`).
- [configs/dnsmasq.conf](file:///Users/den/Developer/ctfd/configs/dnsmasq.conf) — DHCP/DNS сервер для домена `mvsosh.local`.
- [scripts/ctfd-up.sh](file:///Users/den/Developer/ctfd/scripts/ctfd-up.sh) — скрипт гарантированного автоподъема Swarm-сети и стека при загрузке.
- [scripts/setup-host.sh](file:///Users/den/Developer/ctfd/scripts/setup-host.sh) — автоматическая настройка ОС и сборка образов.
- [scripts/verify-offline.sh](file:///Users/den/Developer/ctfd/scripts/verify-offline.sh) — диагностика оффлайн-готовности.
- [staging/CTFd/](file:///Users/den/Developer/ctfd/staging/CTFd/) — исходники для сборки образа `ctfd-whale-local` и тестового задания `test-web`.
- [staging/frp/](file:///Users/den/Developer/ctfd/staging/frp/) — Dockerfile сборки `local-frp`.
- [systemd/ctfd-compose.service](file:///Users/den/Developer/ctfd/systemd/ctfd-compose.service) — unit автозапуска.
