# 🚀 Руководство по установке MTProxyMax Native

Пошаговая инструкция по установке и настройке MTProxyMax Native — версии без Docker.

---

## 📋 Содержание

1. [Требования](#требования)
2. [Быстрая установка](#быстрая-установка)
3. [Пошаговая установка](#пошаговая-установка)
4. [Настройка после установки](#настройка-после-установки)
5. [Проверка работы](#проверка-работы)
6. [Установка веб-интерфейса](#установка-веб-интерфейса)
7. [Установка Telegram-бота](#установка-telegram-бота)
8. [Обновление](#обновление)
9. [Удаление](#удаление)

---

## Требования

### Минимальные

| Компонент | Требование |
|-----------|------------|
| ОС | Linux (Ubuntu 18.04+, Debian 10+, CentOS 7+) |
| CPU | 1 ядро |
| RAM | 256 MB |
| Disk | 100 MB |
| Bash | 4.2+ |

### Рекомендуемые

| Компонент | Требование |
|-----------|------------|
| ОС | Ubuntu 22.04 / Debian 11+ |
| CPU | 2 ядра |
| RAM | 512 MB |
| Disk | 500 MB |
| Python | 3.10+ (для веб-интерфейса и бота) |

---

## Быстрая установка

Одна команда для установки всех компонентов:

```bash
curl -fsSL https://raw.githubusercontent.com/SamNet-dev/MTProxyMax/main/install_native.sh | sudo bash
```

Или вручную:

```bash
# Клонировать репозиторий
git clone https://github.com/SamNet-dev/MTProxyMax.git
cd MTProxyMax

# Запустить установщик
sudo bash install_native.sh
# Выбрать: [5] Всё сразу
```

---

## Пошаговая установка

### Шаг 1: Обновление системы

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt upgrade -y
```

**CentOS/RHEL:**
```bash
sudo yum update -y
```

### Шаг 2: Установка зависимостей

**Ubuntu/Debian:**
```bash
sudo apt install -y curl git wget openssl qrencode python3 python3-pip python3-venv
```

**CentOS/RHEL:**
```bash
sudo yum install -y curl git wget openssl qrencode python3 python3-pip
```

**Alpine:**
```bash
apk add --no-cache curl git wget openssl qrencode python3 py3-pip
```

### Шаг 3: Клонирование репозитория

```bash
cd /opt
sudo git clone https://github.com/SamNet-dev/MTProxyMax.git
cd MTProxyMax
```

### Шаг 4: Установка движка telemt

```bash
sudo bash engine/install_engine.sh
```

Скрипт автоматически:
- Проверит наличие Rust
- Скачает готовый бинарник или соберёт из исходников
- Создаст systemd-сервис `mtproxymax-engine`

**Проверка:**
```bash
systemctl status mtproxymax-engine
```

### Шаг 5: Установка скрипта управления

```bash
sudo cp mtproxymax-native.sh /opt/mtproxymax/
sudo cp locale.sh /opt/mtproxymax/
sudo cp -r locales /opt/mtproxymax/
sudo chmod +x /opt/mtproxymax/mtproxymax-native.sh
sudo ln -s /opt/mtproxymax/mtproxymax-native.sh /usr/local/bin/mtproxymax
```

**Проверка:**
```bash
mtproxymax --help
```

### Шаг 6: Настройка первого секрета

```bash
# Добавить пользователя
sudo mtproxymax secret add alice

# Установить лимиты (опционально)
sudo mtproxymax secret setlimit alice conns 3
sudo mtproxymax secret setlimit alice quota 10G
```

### Шаг 7: Запуск прокси

```bash
# Запустить
sudo mtproxymax start

# Проверить статус
sudo mtproxymax status

# Получить ссылку
sudo mtproxymax secret link alice
```

---

## Настройка после установки

### Изменение порта

```bash
sudo nano /opt/mtproxymax/settings.conf
# Изменить: PROXY_PORT='8443'

sudo mtproxymax restart
```

### Изменение домена FakeTLS

```bash
sudo nano /opt/mtproxymax/settings.conf
# Изменить: PROXY_DOMAIN='example.com'

sudo mtproxymax restart
```

### Установка Ad-Tag (монетизация)

1. Получите тег в [@MTProxyBot](https://t.me/MTProxyBot)
2. Добавьте в конфиг:

```bash
sudo nano /opt/mtproxymax/settings.conf
# Добавить: AD_TAG='00000000000000000000000000000000'

sudo mtproxymax restart
```

---

## Проверка работы

### 1. Проверка статуса

```bash
sudo mtproxymax status
```

Ожидаемый вывод:
```
╔════════════════════════════════════════╗
║  MTProxyMax Engine Status              ║
╚════════════════════════════════════════╝

  Версия:     3.3.32
  Бинарник:   /opt/mtproxymax/engine/telemt
              ✓ установлен

  Статус:     ● запущен
  PID:        12345

  Порт:       443
  Домен:      cloudflare.com
```

### 2. Проверка подключения

```bash
# Проверка порта
sudo ss -tlnp | grep :443

# Проверка процесса
ps aux | grep telemt
```

### 3. Тестирование ссылки

1. Откройте Telegram
2. Вставьте ссылку из `mtproxymax secret link <name>`
3. Нажмите "Подключиться"
4. Проверьте IP через [@ShowIPBot](https://t.me/ShowIPBot)

---

## Установка веб-интерфейса

### Шаг 1: Установка зависимостей

```bash
cd /opt/mtproxymax/web

# Виртуальное окружение
python3 -m venv venv
source venv/bin/activate

# Зависимости
pip install -r requirements.txt
```

### Шаг 2: Настройка сервиса

```bash
sudo cp mtproxymax-web.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mtproxymax-web
sudo systemctl start mtproxymax-web
```

### Шаг 3: Проверка

Откройте в браузере: `http://YOUR_SERVER_IP:8080`

**Проверка статуса:**
```bash
systemctl status mtproxymax-web
```

**Логи:**
```bash
sudo journalctl -u mtproxymax-web -f
```

---

## Установка Telegram-бота

### Шаг 1: Создание бота

1. Откройте [@BotFather](https://t.me/BotFather)
2. Отправьте `/newbot`
3. Введите имя бота (например, `My Proxy Bot`)
4. Введите username бота (например, `my_proxy_bot`)
5. Сохраните полученный токен

### Шаг 2: Получение Admin ID

1. Откройте [@userinfobot](https://t.me/userinfobot)
2. Нажмите "Start"
3. Сохраните полученный ID

### Шаг 3: Настройка

```bash
cd /opt/mtproxymax/bot

# Копирование конфига
sudo cp .env.example .env

# Редактирование
sudo nano .env
```

Вставьте значения:
```ini
MTPOXYMAX_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz
MTPOXYMAX_ADMIN_IDS=123456789
```

### Шаг 4: Установка сервиса

```bash
# Виртуальное окружение
python3 -m venv venv
source venv/bin/activate

# Зависимости
pip install -r requirements.txt

# Сервис
sudo cp mtproxymax-bot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mtproxymax-bot
sudo systemctl start mtproxymax-bot
```

### Шаг 5: Проверка

1. Откройте бота в Telegram
2. Нажмите `/start`
3. Должно появиться главное меню

**Проверка статуса:**
```bash
systemctl status mtproxymax-bot
```

**Логи:**
```bash
sudo journalctl -u mtproxymax-bot -f
```

---

## Обновление

### Обновление скрипта

```bash
cd /opt/mtproxymax
sudo git pull
sudo cp mtproxymax-native.sh /opt/mtproxymax/
sudo chmod +x /opt/mtproxymax/mtproxymax-native.sh
```

### Обновление движка

```bash
sudo mtproxymax engine rebuild
```

Или через установщик:
```bash
sudo bash engine/install_engine.sh
```

### Обновление веб-интерфейса

```bash
cd /opt/mtproxymax/web
sudo git pull
sudo cp -r templates /opt/mtproxymax/web/
sudo systemctl restart mtproxymax-web
```

### Обновление бота

```bash
cd /opt/mtproxymax/bot
sudo git pull
sudo systemctl restart mtproxymax-bot
```

---

## Удаление

### Быстрое удаление

```bash
sudo mtproxymax stop
sudo systemctl stop mtproxymax-web mtproxymax-bot mtproxymax-engine
sudo systemctl disable mtproxymax-web mtproxymax-bot mtproxymax-engine

sudo rm -rf /opt/mtproxymax
sudo rm /usr/local/bin/mtproxymax
```

### Полное удаление

```bash
# Остановка сервисов
sudo systemctl stop mtproxymax-web mtproxymax-bot mtproxymax-engine
sudo systemctl disable mtproxymax-web mtproxymax-bot mtproxymax-engine
sudo rm /etc/systemd/system/mtproxymax-*.service

# Удаление файлов
sudo rm -rf /opt/mtproxymax

# Удаление конфигов
sudo rm -rf /opt/mtproxy

# Очистка systemd
sudo systemctl daemon-reload

# Удаление логов
sudo rm -f /var/log/mtproxymax.log
```

---

## Поддержка

### Логи

```bash
# Основной лог
sudo tail -f /var/log/mtproxymax.log

# Через journalctl
sudo journalctl -u mtproxymax-engine -f
sudo journalctl -u mtproxymax-web -f
sudo journalctl -u mtproxymax-bot -f
```

### Диагностика

```bash
# Статус
sudo mtproxymax status

# Проверка конфига
cat /opt/mtproxymax/mtproxy/config.toml

# Проверка порта
sudo ss -tlnp | grep :443

# Проверка процесса
ps aux | grep telemt
```

### Частые проблемы

| Проблема | Решение |
|----------|---------|
| Порт занят | Измените порт в settings.conf |
| Недостаточно памяти | Увеличьте RAM или уменьшите concurrency |
| Бот не отвечает | Проверьте токен в .env |
| Веб-интерфейс недоступен | Проверьте firewall: `sudo ufw allow 8080` |

---

## Контакты

- **GitHub:** https://github.com/SamNet-dev/MTProxyMax
- **Документация:** /opt/mtproxymax/docs/README.md

---

Copyright (c) 2026 SamNet Technologies
