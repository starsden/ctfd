# Автономный CTF-сервер для локальной сети без интернета

Комплексное решение для проведения CTF-соревнований в закрытой локальной сети (offline environment):
- **Сервер:** Debian 13 (Trixie) в VirtualBox.
- **Платформа соревнований:** CTFd + MariaDB + Redis.
- **Динамические Docker-задания:** Плагин `ctfd-whale` (выдача персонального контейнера каждому участнику/команде с таймером и динамическим флагом).
- **Сетевая служба:** Лёгкий `dnsmasq` (DHCP + DNS `ctf.local`).
- **Участники:** Виртуальные машины Kali Linux в VirtualBox.
- **Автоматизация:** Полный автозапуск всех сервисов на старте ОС без ручного вмешательства.
- **Оффлайн-режим:** 100% автономная работа без необходимости внешнего интернета.

---

## Быстрый старт

### 1. Подготовка на этапе с интернетом (на сервере Debian 13)
```bash
git clone <ваш_репозиторий> /opt/ctfd
cd /opt/ctfd

# Установка зависимостей, docker, dnsmasq, swarm, systemd
sudo bash ./scripts/setup-host.sh

# Кэширование всех образов CTFd и заданий
sudo bash ./scripts/prepull-images.sh
```

### 2. Запуск и перевод в оффлайн
```bash
# Запуск CTFd сервиса
sudo systemctl start ctfd.service

# Проверка оффлайн-готовности
sudo bash ./scripts/verify-offline.sh
```

### 3. Подключение участников (Kali Linux)
- В настройках VM Kali Linux установите сетевой адаптер в **«Внутренняя сеть» (Internal Network)** с именем `ctf-net`.
- Запустите Kali Linux. Сеть настроится автоматически по DHCP (`192.168.100.x`).
- В браузере откройте: **`http://ctf.local`** (или `http://192.168.100.1`).

---

## Архитектура сети

```
+-----------------------------------------------------------------------------------+
|                        VirtualBox Внутренняя сеть: 'ctf-net'                      |
|                                                                                   |
|  +-------------------------------------+      +--------------------------------+  |
|  |       VM Debian 13 (CTFd Сервер)    |      |    VM Kali Linux (Участник 1)  |  |
|  |  IP: 192.168.100.1 / 255.255.255.0  |      |  IP: 192.168.100.50 (DHCP)     |  |
|  |                                     |      |  DNS: 192.168.100.1            |  |
|  |  * dnsmasq (DHCP & DNS ctf.local)   |      +--------------------------------+  |
|  |  * Docker Swarm (name=linux-1)      |                                          |
|  |  * CTFd Web (:80, :8000)            |      +--------------------------------+  |
|  |  * Whale динамические порты         |      |    VM Kali Linux (Участник 2)  |  |
|  |    (:20000 - :20500)                |      |  IP: 192.168.100.51 (DHCP)     |  |
|  +-------------------------------------+      +--------------------------------+  |
+-----------------------------------------------------------------------------------+
```

---

## Структура репозитория

- [docker-compose.yml](file:///Users/den/Developer/ctfd/docker-compose.yml) — сервисы CTFd, MariaDB, Redis с пробросом Docker-сокета.
- [WALKTHROUGH.md](file:///Users/den/Developer/ctfd/WALKTHROUGH.md) — подробное пошаговое руководство администратора с настройками плагина.
- [configs/dnsmasq.conf](file:///Users/den/Developer/ctfd/configs/dnsmasq.conf) — конфигурация легкого DHCP-сервера и локальной зоны DNS.
- [configs/10-static-enp0s3.network](file:///Users/den/Developer/ctfd/configs/10-static-enp0s3.network) — конфигурация статического IP для `systemd-networkd`.
- [configs/interfaces](file:///Users/den/Developer/ctfd/configs/interfaces) — конфигурация статического IP для `ifupdown`.
- [systemd/ctfd.service](file:///Users/den/Developer/ctfd/systemd/ctfd.service) — unit-файл автозапуска CTFd при старте ОС.
- [scripts/setup-host.sh](file:///Users/den/Developer/ctfd/scripts/setup-host.sh) — скрипт автоматической установки и настройки Debian 13.
- [scripts/prepull-images.sh](file:///Users/den/Developer/ctfd/scripts/prepull-images.sh) — скрипт предварительного скачивания всех образов.
- [scripts/export-offline-bundle.sh](file:///Users/den/Developer/ctfd/scripts/export-offline-bundle.sh) — экспорт образов в архив (для air-gapped переноса).
- [scripts/import-offline-bundle.sh](file:///Users/den/Developer/ctfd/scripts/import-offline-bundle.sh) — импорт образов из архива.
- [scripts/verify-offline.sh](file:///Users/den/Developer/ctfd/scripts/verify-offline.sh) — автоматическая самодиагностика готовности к оффлайну.
- [challenges/web-sample/](file:///Users/den/Developer/ctfd/challenges/web-sample/) — готовый пример динамического задания с генерацией флага.
