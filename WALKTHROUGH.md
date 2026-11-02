# Руководство администратора: Развертывание автономного CTF-сервера

В этом документе содержится детальная пошаговая инструкция по подготовке, конфигурированию и тестированию инфраструктуры для проведения оффлайн CTF соревнований.

---

## 1. Подготовка виртуальной машины сервера (Debian 13)

### Конфигурация виртуальной машины VirtualBox для сервера:
- **ОС:** Debian 13 (64-bit).
- **Процессор:** от 4 vCPU.
- **Оперативная память:** от 4 до 8 ГБ.
- **Диск:** 40+ ГБ.
- **Сетевой адаптер 1:** **NAT** (интерфейс `enp0s3`) — для выхода в интернет во время подготовки (скачивание пакетов и образов).
- **Сетевой адаптер 2:** **Внутренняя сеть (Internal Network)** (интерфейс `enp0s8`) с именем **`ctf-net`** — для подключения машин участников (Kali Linux). Неразборчивый режим (Promiscuous Mode): **Разрешить всё**.

> **Важно:** Сеть участников привязывается именно к **Адаптеру 2 (`enp0s8`)**! На нем настраивается статический IP `192.168.100.1` и запускается DHCP-сервер. Адаптер 1 (`enp0s3`) остается для доступа в интернет или отключается в день соревнований.

---

## 2. Развертывание платформы (этап с интернетом)

### Шаг 2.1. Клонирование репозитория
```bash
sudo su -
mkdir -p /opt/ctfd
cd /opt/ctfd
git clone <URL_РЕПОЗИТОРИЯ> .
```

### Шаг 2.2. Запуск базовой настройки
Скрипт `scripts/setup-host.sh` принимает имя сетевого адаптера для участников (по умолчанию автоматически выбирает `enp0s8`):
```bash
chmod +x scripts/*.sh
./scripts/setup-host.sh enp0s8
```

Скрипт автоматически:
1. Выберет интерфейс `enp0s8` (Адаптер 2).
2. Проверит и остановит системные `apache2` / `nginx`, освобождая порт 80.
3. Установит Docker, Docker Compose, `dnsmasq` и утилиты.
4. Пропишет постоянную конфигурацию статического IP `192.168.100.1` в `/etc/network/interfaces.d/ctf.cfg` (сохраняется после любых перезагрузок) и поднимет интерфейс.
5. Настроит `/etc/dnsmasq.d/ctf.conf` на интерфейс `enp0s8` для выдачи IP участникам (`192.168.100.50-200`) и разрешения домена `ctf.local`.
6. Инициализирует Docker Swarm на адресе `192.168.100.1` и назначит метку `name=linux-1`.
7. Клонирует плагин `ctfd-whale`.
8. Настроит системный юнит `ctfd.service` для автозапуска при загрузке ОС.

### Быстрое ручное исправление сетевых настроек (если скрипт уже запускался ранее):
Если на вашей ВМ уже выполнялась настройка, достаточно применить следующие команды:

```bash
# 1. Зафиксировать статический IP на enp0s8 в /etc/network/interfaces.d/ctf.cfg
sudo mkdir -p /etc/network/interfaces.d
cat << 'EOF' | sudo tee /etc/network/interfaces.d/ctf.cfg
auto enp0s8
allow-hotplug enp0s8
iface enp0s8 inet static
    address 192.168.100.1
    netmask 255.255.255.0
EOF

# Проверить подключение каталога interfaces.d
grep -q "interfaces.d" /etc/network/interfaces || echo "source /etc/network/interfaces.d/*" | sudo tee -a /etc/network/interfaces

# Применить IP немедленно
sudo ip addr replace 192.168.100.1/24 dev enp0s8
sudo ip link set dev enp0s8 up

# 2. Исправить привязку dnsmasq к адаптеру enp0s8 и удалить устаревшие конфиги
sudo rm -f /etc/dnsmasq.d/ctfd.conf
sudo sed -i 's/interface=enp0s3/interface=enp0s8/' /etc/dnsmasq.d/ctf.conf
sudo systemctl restart dnsmasq
```

---

## 3. Кэширование всех Docker-образов

```bash
./scripts/prepull-images.sh
```
Этот скрипт скачивает базовые образы CTFd (`ctfd/ctfd:latest`, `mariadb:10.11`, `redis:7-alpine`), базовые образы заданий и собирает тестовое задание `ctf/web-sample:latest`.

---

## 4. Конфигурация плагина CTFd-Whale

1. Запустите сервис:
   ```bash
   systemctl start ctfd.service
   ```
2. Откройте в браузере `http://192.168.100.1` (или `http://ctf.local`).
3. Заполните первоначальный мастер настройки CTFd.
4. Перейдите в **Admin Panel** -> вкладка **Whale**:
   - **Docker Node**: `linux-1`.
   - **Auto Connect Network**: включить.
   - **Docker Host**: оставить пустым или `unix:///var/run/docker.sock`.
   - **Port Range**: `20000-20500`.
   - **Routing Mode**: `Direct`.
   - **Challenge Timeout**: `1800` (секунд).
   - **Container Max Count**: `1`.
5. Нажмите **Update**.

---

## 5. Создание динамического задания в CTFd

1. В Admin Panel перейдите в **Challenges** -> **+** (New Challenge).
2. Выберите тип: **`dynamic_docker`**.
3. Заполните поля:
   - **Name**: `Warmup Web Challenge`.
   - **Category**: `Web`.
   - **Docker Image**: `ctf/web-sample:latest`.
   - **Frp Redirect Type**: `Direct`.
   - **Redirect Port**: `80`.
   - **Dynamic Flag**: включить.
4. Нажмите **Create**.

---

## 6. Проверка оффлайн-готовности (День соревнований)

1. Отключите сетевой кабель на Адаптере 1 (NAT) в свойствах VirtualBox, либо выключите его.
2. Запустите проверку:
   ```bash
   ./scripts/verify-offline.sh
   ```

---

## 7. Инструкция для участников (Kali Linux)

1. **В настройках VirtualBox ВМ Kali Linux:**
   - Сеть -> Адаптер 1:
   - Тип подключения: **Внутренняя сеть (Internal Network)**.
   - Имя сети: **`ctf-net`**.
   - Неразборчивый режим: **Разрешить виртуальным машинам** или **Разрешить всё**.

2. **Запуск:**
   - Запустите ВМ Kali Linux.
   - В терминале Kali убедитесь в получении адреса:
     ```bash
     ip addr show
     # Должен появиться адрес из диапазона 192.168.100.50-200
     ping -c 2 ctf.local
     ```
   - Откройте браузер и перейдите на **`http://ctf.local`**.
