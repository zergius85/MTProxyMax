# MTProxyMax Native — Локальная версия без Docker

Полная переработка MTProxyMax для работы без Docker, с русским интерфейсом, веб-панелью и Telegram-ботом.

## 📋 Возможности

- ✅ **Работа без Docker** — нативный запуск telemt
- ✅ **Русский язык** — полный перевод интерфейса
- ✅ **Веб-интерфейс** — управление через браузер
- ✅ **Telegram-бот** — inline-меню с кнопками
- ✅ **TUI меню** — интерактивное управление в терминале
- ✅ **CLI команды** — для скриптов и автоматизации

---

## 🚀 Быстрый старт

### 1. Установка движка

```bash
cd /opt/mtproxymax
sudo bash engine/install_engine.sh
```

Скрипт:
- Установит зависимости (Rust, curl, git)
- Скачает или соберёт telemt
- Создаст systemd-сервис

### 2. Установка скрипта управления

```bash
sudo cp mtproxymax-native.sh /opt/mtproxymax/
sudo cp locale.sh /opt/mtproxymax/
sudo cp -r locales /opt/mtproxymax/
sudo chmod +x /opt/mtproxymax/mtproxymax-native.sh
```

### 3. Первое использование

```bash
# Открыть TUI меню
sudo mtproxymax-native.sh menu

# Или через CLI
sudo mtproxymax-native.sh secret add myuser
sudo mtproxymax-native.sh start
sudo mtproxymax-native.sh status
```

---

## 📖 Структура проекта

```
MTProxyMax/
├── engine/
│   ├── install_engine.sh    # Установка telemt
│   └── enginectl.sh         # Управление движком
├── locales/
│   ├── ru.json              # Русский перевод
│   └── en.json              # English translation
├── web/
│   ├── app.py               # FastAPI веб-сервер
│   ├── requirements.txt     # Python зависимости
│   ├── templates/
│   │   └── index.html       # Главная страница
│   └── static/              # CSS, JS, изображения
├── bot/
│   ├── bot.py               # Telegram бот
│   ├── requirements.txt     # Python зависимости
│   └── .env.example         # Шаблон конфига
├── locale.sh                # Модуль локализации
├── mtproxymax-native.sh     # Основной скрипт (без Docker)
└── README_NATIVE.md         # Этот файл
```

---

## 🖥️ Веб-интерфейс

### Установка

```bash
cd /opt/mtproxymax/web

# Создать виртуальное окружение
python3 -m venv venv
source venv/bin/activate

# Установить зависимости
pip install -r requirements.txt

# Запустить сервер
python app.py
```

### Доступ

Откройте в браузере: `http://YOUR_SERVER_IP:8080`

### Функции веб-интерфейса:

- 📊 Дашборд со статусом
- 👥 Управление секретами (добавить, удалить, лимиты)
- ⚙️ Настройки прокси
- 📋 Просмотр логов
- 🚀 Запуск/остановка движка

---

## 🤖 Telegram-бот

### Настройка

1. Создайте бота через [@BotFather](https://t.me/BotFather)
2. Получите токен
3. Узнайте свой Telegram ID через [@userinfobot](https://t.me/userinfobot)

```bash
cd /opt/mtproxymax/bot

# Создать .env файл
cp .env.example .env
nano .env  # Вставьте токен и ID

# Установить зависимости
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Запустить бота
python bot.py
```

### Команды бота

| Кнопка | Описание |
|--------|----------|
| 📊 Статус | Статус прокси и статистика |
| 👥 Секреты | Управление секретами |
| 🔗 Моя ссылка | Ссылка на подключение |
| 📈 Трафик | Статистика трафика |
| ⚙️ Настройки | Порт, домен, Ad-Tag |
| 🔧 Управление | Запуск/остановка/перезапуск |
| 📖 Помощь | Справка по боту |

---

## 📝 CLI команды

### Управление секретами

```bash
# Добавить секрет
sudo mtproxymax-native.sh secret add alice

# Список секретов
sudo mtproxymax-native.sh secret list

# Удалить секрет
sudo mtproxymax-native.sh secret remove alice

# Включить/отключить
sudo mtproxymax-native.sh secret enable alice
sudo mtproxymax-native.sh secret disable alice

# Обновить ключ
sudo mtproxymax-native.sh secret rotate alice

# Показать ссылку
sudo mtproxymax-native.sh secret link alice

# Показать QR
sudo mtproxymax-native.sh secret qr alice

# Установить лимиты
sudo mtproxymax-native.sh secret setlimit alice conns 3    # 3 устройства
sudo mtproxymax-native.sh secret setlimit alice quota 10G  # 10 GB трафика
sudo mtproxymax-native.sh secret setlimit alice expires 2026-12-31  # Срок действия
```

### Управление прокси

```bash
# Статус
sudo mtproxymax-native.sh status

# Запустить
sudo mtproxymax-native.sh start

# Остановить
sudo mtproxymax-native.sh stop

# Перезапустить
sudo mtproxymax-native.sh restart

# Логи
sudo mtproxymax-native.sh logs
```

### Настройки

```bash
# Открыть меню настроек
sudo mtproxymax-native.sh settings
```

---

## 🔧 Конфигурационные файлы

| Файл | Описание |
|------|----------|
| `/opt/mtproxymax/settings.conf` | Настройки прокси (порт, домен) |
| `/opt/mtproxymax/secrets.conf` | База секретов |
| `/opt/mtproxymax/mtproxy/config.toml` | Конфиг telemt (генерируется автоматически) |
| `/opt/mtproxymax/engine/telemt` | Бинарник telemt |

---

## 🛡️ Безопасность

- Все секреты хранятся в `/opt/mtproxymax/secrets.conf` с правами `600`
- Для работы требуется root
- Telegram-бот проверяет ID администраторов
- Веб-интерфейс работает только на localhost (по умолчанию)

---

## 📊 Системные требования

| Требование | Значение |
|------------|----------|
| ОС | Linux (Ubuntu, Debian, CentOS, AlmaLinux) |
| RAM | 256 MB минимум |
| Disk | 100 MB |
| Bash | 4.2+ |
| Python | 3.8+ (для веб-интерфейса и бота) |

---

## 🔨 Сборка telemt из исходников

Если автоматическая загрузка не удалась:

```bash
cd /opt/mtproxymax/engine/src
git clone https://github.com/telemt/telemt.git
cd telemt
git checkout a383efc  # v3.3.32
cargo build --release
cp target/release/telemt /opt/mtproxymax/engine/
```

---

## 📞 Поддержка

- GitHub: https://github.com/SamNet-dev/MTProxyMax
- Telegram: @MTProxyMax (пример)

---

## 📄 Лицензия

- Скрипт: MIT License
- telemt: TPL-3 License

Copyright (c) 2026 SamNet Technologies
