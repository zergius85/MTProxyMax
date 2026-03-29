# 📘 Документация MTProxyMax Native

Полная документация по установке, настройке и использованию MTProxyMax Native — версии без Docker.

---

## 📖 Содержание

1. [Введение](#введение)
2. [Архитектура](#архитектура)
3. [Установка](#установка)
4. [Настройка](#настройка)
5. [Использование](#использование)
6. [Веб-интерфейс](#веб-интерфейс)
7. [Telegram-бот](#telegram-бот)
8. [API референс](#api-референс)
9. [Устранение проблем](#устранение-проблем)
10. [FAQ](#faq)

---

## Введение

**MTProxyMax Native** — это полнофункциональный менеджер MTProto-прокси для Telegram, работающий без Docker. 

### Ключевые особенности

| Особенность | Описание |
|-------------|----------|
| 🚀 **Без Docker** | Нативный запуск telemt напрямую в системе |
| 🇷🇺 **Русский язык** | Полный перевод интерфейса и документации |
| 🌐 **Веб-интерфейс** | Управление через браузер с любого устройства |
| 🤖 **Telegram-бот** | Inline-меню с кнопками для мобильного управления |
| 📊 **Мониторинг** | Статистика трафика, подключений, событий |
| 🔒 **Безопасность** | Мультипользовательские секреты с лимитами |

### Отличия от Docker-версии

| Функция | Docker | Native |
|---------|--------|--------|
| Запуск | Контейнер | Нативный бинарник |
| Зависимости | Минимальные | Rust, Python |
| Потребление RAM | ~50 MB | ~30 MB |
| Обновление | `docker pull` | `cargo build` |
| Логирование | `docker logs` | Файлы логов |

---

## Архитектура

### Компоненты системы

```
┌─────────────────────────────────────────────────────────┐
│                    MTProxyMax Native                     │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌────────────┐ │
│  │   CLI (Bash) │    │  Web (FastAPI)│    │  Bot (aiogram)│
│  │              │    │               │    │              │
│  │  - TUI меню  │    │  - Dashboard  │    │  - Inline    │
│  │  - Команды   │    │  - API        │    │    меню      │
│  └──────┬───────┘    └───────┬───────┘    └──────┬───────┘
│         │                    │                    │       │
│         └────────────────────┼────────────────────┘       │
│                              │                             │
│                    ┌─────────▼─────────┐                  │
│                    │  mtproxymax-native.sh │              │
│                    │   (управление)     │                  │
│                    └─────────┬─────────┘                  │
│                              │                             │
│                    ┌─────────▼─────────┐                  │
│                    │    telemt.bin     │                  │
│                    │   (Rust engine)   │                  │
│                    └─────────┬─────────┘                  │
│                              │                             │
└──────────────────────────────┼─────────────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │   Telegram Servers  │
                    │      Port 443       │
                    └─────────────────────┘
```

### Структура файлов

```
/opt/mtproxymax/
├── engine/
│   ├── telemt              # Бинарник telemt
│   ├── install_engine.sh   # Скрипт установки
│   └── enginectl.sh        # Управление движком
├── mtproxy/
│   └── config.toml         # Конфигурация telemt
├── locales/
│   ├── ru.json             # Русский перевод
│   └── en.json             # English
├── web/
│   ├── app.py              # FastAPI сервер
│   ├── templates/          # HTML шаблоны
│   └── static/             # CSS, JS
├── bot/
│   ├── bot.py              # Telegram бот
│   └── .env                # Конфигурация бота
├── settings.conf           # Настройки прокси
├── secrets.conf            # База секретов
├── mtproxymax-native.sh    # Главный скрипт
└── mtproxy.log             # Логи
```

---

## Установка

### Системные требования

| Требование | Минимум | Рекомендуется |
|------------|---------|---------------|
| ОС | Linux (any) | Ubuntu 22.04 / Debian 11+ |
| RAM | 256 MB | 512 MB |
| Disk | 100 MB | 500 MB |
| CPU | 1 core | 2 cores |
| Bash | 4.2+ | 5.0+ |
| Python | 3.8+ | 3.10+ |

### Быстрая установка (рекомендуется)

```bash
# Скачать репозиторий
git clone https://github.com/SamNet-dev/MTProxyMax.git
cd MTProxyMax

# Запустить установщик
sudo bash install_native.sh
# Выбрать: [5] Всё сразу
```

### Пошаговая установка

#### Шаг 1: Установка зависимостей

**Ubuntu/Debian:**
```bash
sudo apt update
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

#### Шаг 2: Установка движка telemt

```bash
cd /opt/mtproxymax
sudo bash engine/install_engine.sh
```

Скрипт автоматически:
- Проверит наличие Rust
- Скачает готовый бинарник или соберёт из исходников
- Создаст systemd-сервис

#### Шаг 3: Установка скрипта управления

```bash
sudo cp mtproxymax-native.sh /opt/mtproxymax/
sudo cp locale.sh /opt/mtproxymax/
sudo cp -r locales /opt/mtproxymax/
sudo chmod +x /opt/mtproxymax/mtproxymax-native.sh
sudo ln -s /opt/mtproxymax/mtproxymax-native.sh /usr/local/bin/mtproxymax
```

#### Шаг 4: Установка веб-интерфейса

```bash
cd /opt/mtproxymax/web

# Виртуальное окружение
python3 -m venv venv
source venv/bin/activate

# Зависимости
pip install -r requirements.txt

# Копирование сервиса
sudo cp mtproxymax-web.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mtproxymax-web
sudo systemctl start mtproxymax-web
```

#### Шаг 5: Установка Telegram-бота

```bash
cd /opt/mtproxymax/bot

# Виртуальное окружение
python3 -m venv venv
source venv/bin/activate

# Зависимости
pip install -r requirements.txt

# Конфигурация
cp .env.example .env
nano .env  # Вставить токен и ID

# Сервис
sudo cp mtproxymax-bot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mtproxymax-bot
sudo systemctl start mtproxymax-bot
```

---

## Настройка

### Базовая конфигурация

Откройте TUI меню:
```bash
sudo mtproxymax menu
```

Или используйте CLI:
```bash
# Установить порт
sudo mtproxymax-native.sh secret setlimit myuser conns 3

# Установить домен (для FakeTLS)
# Редактировать settings.conf
sudo nano /opt/mtproxymax/settings.conf

# Установить Ad-Tag (опционально)
# Получить в @MTProxyBot
```

### Настройка секретов

```bash
# Добавить первого пользователя
sudo mtproxymax secret add alice

# Установить лимиты
sudo mtproxymax secret setlimit alice conns 3      # 3 устройства
sudo mtproxymax secret setlimit alice quota 10G    # 10 GB трафика
sudo mtproxymax secret setlimit alice expires 2026-12-31

# Получить ссылку
sudo mtproxymax secret link alice

# Показать QR-код
sudo mtproxymax secret qr alice
```

### Конфигурация Telegram-бота

1. Создайте бота в [@BotFather](https://t.me/BotFather)
2. Получите токен
3. Узнайте свой ID в [@userinfobot](https://t.me/userinfobot)
4. Отредактируйте `.env`:

```bash
nano /opt/mtproxymax/bot/.env
```

```ini
MTPOXYMAX_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz
MTPOXYMAX_ADMIN_IDS=123456789
```

5. Перезапустите бота:
```bash
sudo systemctl restart mtproxymax-bot
```

---

## Использование

### CLI команды

#### Управление прокси

| Команда | Описание |
|---------|----------|
| `mtproxymax start` | Запустить прокси |
| `mtproxymax stop` | Остановить прокси |
| `mtproxymax restart` | Перезапустить |
| `mtproxymax status` | Показать статус |
| `mtproxymax logs` | Показать логи |

#### Управление секретами

| Команда | Описание |
|---------|----------|
| `mtproxymax secret add <name>` | Добавить секрет |
| `mtproxymax secret list` | Список секретов |
| `mtproxymax secret remove <name>` | Удалить секрет |
| `mtproxymax secret enable <name>` | Включить |
| `mtproxymax secret disable <name>` | Отключить |
| `mtproxymax secret rotate <name>` | Обновить ключ |
| `mtproxymax secret link <name>` | Показать ссылку |
| `mtproxymax secret qr <name>` | Показать QR |
| `mtproxymax secret setlimit <name> <type> <value>` | Установить лимит |

Типы лимитов:
- `conns` — максимальное количество подключений (устройств)
- `ips` — максимальное количество уникальных IP
- `quota` — лимит трафика (например, `10G`, `500M`)
- `expires` — дата истечения (например, `2026-12-31`)

### TUI меню

```bash
sudo mtproxymax menu
```

Откроется интерактивное меню:

```
╔═══════════════════════════════════════════════════════╗
║         MTProxyMax Native — Управление прокси         ║
╚═══════════════════════════════════════════════════════╝

  ● Статус: запущен
  Порт: 443
  Домен: cloudflare.com

  ➤ Главное меню
  ─────────────────
  [1] Статус прокси
  [2] Управление секретами
  [3] Запустить прокси
  [4] Остановить прокси
  [5] Перезапустить прокси
  [6] Настройки
  [7] Логи
  [8] Обновить движок
  [0] Выход
```

---

## Веб-интерфейс

### Доступ

Откройте в браузере: `http://YOUR_SERVER_IP:8080`

### Страницы

#### Главная (Dashboard)

- Статус движка (запущен/остановлен)
- Порт и домен
- Количество секретов
- Кнопки управления (старт/стоп/рестарт)

#### Секреты

- Список всех секретов
- Добавление новых
- Редактирование лимитов
- Включение/отключение
- Генерация ссылок

#### Настройки

- Изменение порта
- Смена домена FakeTLS
- Установка Ad-Tag

#### Логи

- Просмотр логов в реальном времени
- Фильтрация по уровню
- Экспорт

---

## Telegram-бот

### Команды

| Команда | Описание |
|---------|----------|
| `/start` | Запустить бота, показать меню |
| `/menu` | Показать главное меню |
| `/status` | Статус прокси |
| `/link` | Ссылка на подключение |
| `/help` | Справка |

### Inline-меню

Главное меню:
```
┌─────────────────────────────┐
│  📊 Статус    👥 Секреты    │
│  🔗 Моя ссылка  📈 Трафик   │
│  ⚙️ Настройки  🔧 Управление│
│  📖 Помощь                  │
└─────────────────────────────┘
```

Меню секретов:
```
┌─────────────────────────────┐
│  ➕ Добавить  📋 Список     │
│  🔄 Обновить  🗑️ Удалить    │
│  🔙 Назад                   │
└─────────────────────────────┘
```

### Настройка уведомлений

Бот автоматически отправляет уведомления:
- 🟢 Прокси запущен
- 🔴 Прокси остановлен
- ⚠️ Квота трафика 80%
- ❌ Секрет истёк

---

## API референс

### Базовый URL

```
http://localhost:8080/api
```

### Endpoints

#### GET /api/status

Получить общий статус.

**Ответ:**
```json
{
  "engine": {
    "running": true,
    "pid": 12345,
    "version": "3.3.32",
    "installed": true
  },
  "settings": {
    "port": 443,
    "domain": "cloudflare.com",
    "ad_tag": "",
    "masking_enabled": true
  },
  "secrets_count": 5,
  "active_secrets_count": 4
}
```

#### GET /api/secrets

Список всех секретов.

**Ответ:**
```json
{
  "secrets": [
    {
      "label": "alice",
      "secret": "abc123...",
      "enabled": true,
      "max_conns": 3,
      "max_ips": 0,
      "quota": "10737418240",
      "expires": "2026-12-31"
    }
  ]
}
```

#### POST /api/secrets

Создать новый секрет.

**Запрос:**
```json
{
  "label": "bob",
  "max_conns": 5,
  "max_ips": 0,
  "quota": "0",
  "expires": "0"
}
```

#### DELETE /api/secrets/{label}

Удалить секрет.

#### POST /api/secrets/{label}/enable

Включить секрет.

#### POST /api/secrets/{label}/disable

Отключить секрет.

#### POST /api/secrets/{label}/rotate

Обновить ключ секрета.

#### PUT /api/secrets/{label}/limits

Обновить лимиты.

**Запрос:**
```json
{
  "max_conns": 10,
  "max_ips": 5,
  "quota": "20G",
  "expires": "2027-01-01"
}
```

#### GET /api/secrets/{label}/link

Получить ссылку на подключение.

**Ответ:**
```json
{
  "link": "tg://proxy?server=1.2.3.4&port=443&secret=ee..."
}
```

#### GET /api/settings

Получить настройки.

#### PUT /api/settings

Обновить настройки.

**Запрос:**
```json
{
  "port": 8443,
  "domain": "example.com",
  "ad_tag": "0000...",
  "masking_enabled": true
}
```

#### POST /api/engine/start

Запустить движок.

#### POST /api/engine/stop

Остановить движок.

#### POST /api/engine/restart

Перезапустить движок.

#### GET /api/logs

Получить логи.

**Параметры:**
- `lines` (int, default: 100) — количество строк

---

## Устранение проблем

### Прокси не запускается

**Проблема:**
```
❌ Ошибка запуска
```

**Решение:**
1. Проверьте логи:
   ```bash
   sudo journalctl -u mtproxymax-engine -f
   ```
2. Проверьте доступность порта:
   ```bash
   sudo ss -tlnp | grep :443
   ```
3. Проверьте конфиг:
   ```bash
   cat /opt/mtproxymax/mtproxy/config.toml
   ```

### Секрет не работает

**Проблема:**
Telegram не подключается.

**Решение:**
1. Проверьте, что секрет включён:
   ```bash
   sudo mtproxymax secret list
   ```
2. Проверьте, что движок запущен:
   ```bash
   sudo mtproxymax status
   ```
3. Пересоздайте ссылку:
   ```bash
   sudo mtproxymax secret link <name>
   ```

### Веб-интерфейс недоступен

**Проблема:**
Браузер не открывает страницу.

**Решение:**
1. Проверьте статус сервиса:
   ```bash
   sudo systemctl status mtproxymax-web
   ```
2. Проверьте порт:
   ```bash
   sudo ss -tlnp | grep :8080
   ```
3. Проверьте логи:
   ```bash
   sudo journalctl -u mtproxymax-web -f
   ```

### Бот не отвечает

**Проблема:**
Бот не реагирует на команды.

**Решение:**
1. Проверьте токен в `.env`:
   ```bash
   cat /opt/mtproxymax/bot/.env
   ```
2. Проверьте статус сервиса:
   ```bash
   sudo systemctl status mtproxymax-bot
   ```
3. Перезапустите бота:
   ```bash
   sudo systemctl restart mtproxymax-bot
   ```

### Ошибка "Too many open files"

**Проблема:**
```
ERROR: Too many open files
```

**Решение:**
1. Увеличьте лимит в systemd:
   ```bash
   sudo systemctl edit mtproxymax-engine
   ```
   
   Добавьте:
   ```ini
   [Service]
   LimitNOFILE=65536
   ```

2. Перезапустите:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart mtproxymax-engine
   ```

---

## FAQ

### Как обновить telemt?

```bash
sudo mtproxymax engine rebuild
```

Или через установщик:
```bash
sudo bash engine/install_engine.sh
```

### Как изменить порт?

1. Через TUI:
   ```bash
   sudo mtproxymax menu
   # [6] Настройки → [1] Изменить порт
   ```

2. Через CLI:
   ```bash
   sudo nano /opt/mtproxymax/settings.conf
   # Изменить PROXY_PORT
   sudo mtproxymax restart
   ```

3. Через веб-интерфейс:
   - Откройте Настройки
   - Измените порт
   - Сохраните

### Как добавить Ad-Tag?

1. Получите тег в [@MTProxyBot](https://t.me/MTProxyBot)
2. Установите:
   ```bash
   sudo nano /opt/mtproxymax/settings.conf
   # AD_TAG='ваш_тег'
   sudo mtproxymax restart
   ```

### Как ограничить пользователя?

```bash
# 3 устройства
sudo mtproxymax secret setlimit alice conns 3

# 10 GB трафика
sudo mtproxymax secret setlimit alice quota 10G

# До 31 декабря 2026
sudo mtproxymax secret setlimit alice expires 2026-12-31
```

### Как посмотреть трафик?

Через веб-интерфейс:
- Откройте страницу секретов
- Нажмите на имя пользователя
- увидите статистику

Через Prometheus (если настроен):
```bash
curl http://localhost:9090/metrics
```

### Как сделать резервную копию?

```bash
sudo tar -czf mtproxymax-backup.tar.gz \
  /opt/mtproxymax/settings.conf \
  /opt/mtproxymax/secrets.conf \
  /opt/mtproxymax/mtproxy/config.toml
```

### Как перенести на другой сервер?

1. Создайте бэкап (см. выше)
2. Установите MTProxyMax на новом сервере
3. Восстановите файлы:
   ```bash
   sudo tar -xzf mtproxymax-backup.tar.gz -C /
   sudo mtproxymax restart
   ```

### Как отключить маскировку?

```bash
sudo nano /opt/mtproxymax/settings.conf
# MASKING_ENABLED='false'
sudo mtproxymax restart
```

⚠️ **Внимание:** Без маскировки прокси легче обнаружить и заблокировать.

---

## Поддержка

- **GitHub:** https://github.com/SamNet-dev/MTProxyMax
- **Документация:** `/opt/mtproxymax/README_NATIVE.md`
- **Логи:** `/var/log/mtproxymax.log`

---

## Лицензия

- Скрипт MTProxyMax: MIT License
- telemt engine: TPL-3 License

Copyright (c) 2026 SamNet Technologies
