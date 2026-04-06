<p align="center">
  <h1 align="center">MTProxyMax</h1>
  <p align="center"><b>Ультимативный менеджер MTProto прокси для Telegram</b></p>
  <p align="center">
    Один скрипт. Полный контроль. Никаких хлопот.
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/version-1.0.4-brightgreen" alt="Версия"/>
    <img src="https://img.shields.io/badge/license-MIT-blue" alt="Лицензия"/>
    <img src="https://img.shields.io/badge/engine-Rust_(telemt_3.x)-orange" alt="Движок"/>
    <img src="https://img.shields.io/badge/platform-Linux-lightgrey" alt="Платформа"/>
    <img src="https://img.shields.io/badge/bash-4.2+-yellow" alt="Bash"/>
    <img src="https://img.shields.io/badge/docker-multi--arch-blue" alt="Docker"/>
  </p>
</p>

<p align="center">
  <b>Выбери язык:</b><br/>
  🇷🇺 <a href="README_RU.md"><b>Русский</b></a> &bull;
  🇬🇧 <a href="README_EN.md"><b>English</b></a>
</p>

---

## 🚀 Быстрый старт

### Установка в одну строку

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/SamNet-dev/MTProxyMax/main/install.sh)"
```

### После установки

```bash
mtproxymax           # Открыть интерактивный TUI
mtproxymax status    # Проверить состояние прокси
```

---

## 🔥 Ключевые возможности

- 🔐 **Мультипользовательские секреты** с квотами, лимитами устройств и датами истечения
- 🤖 **Телеграм-бот** с 17 командами — управляй всем с телефона
- 🗂️ **Репликация** — синхронизация конфигурации master-slave через rsync+SSH
- 🖥️ **Интерактивный TUI** — управление через меню, без запоминания команд
- 📊 **Метрики Prometheus** — реальная статистика трафика на пользователя
- 🔗 **Цепочки прокси** — маршрутизация через SOCKS5/SOCKS4 вышестоящие
- 🔄 **Автовосстановление** — детекция простоев, авто-перезапуск, оповещения в Telegram
- 🐳 **Docker-образы** — установка за секунды (multi-arch: amd64 + arm64)
- 🌍 **Геоблокировка** — блокировка стран на уровне CIDR через iptables
- 💰 **Ad-Tag** — монетизация через рекламные каналы Telegram

---

## 📖 Документация

Полная документация доступна на выбранном языке:

| Язык | Файл |
|------|------|
| 🇷🇺 Русский | [README_RU.md](README_RU.md) |
| 🇬🇧 English | [README_EN.md](README_EN.md) |

**Что внутри:**
- Подробное описание всех возможностей
- Рецепты управления пользователями
- Справочник CLI (полный список команд)
- Архитектура проекта
- Сравнение с другими решениями (mtg, официальный MTProxy)
- Журнал изменений (Changelog)
- Системные требования

---

## 💻 Нативная установка (без Docker)

Для тех, кто хочет работать без Docker:

```bash
curl -fsSL https://raw.githubusercontent.com/zergius85/MTProxyMax/main/install_native.sh -o install_native.sh
chmod +x install_native.sh
sudo ./install_native.sh
```

Подробнее в [README_NATIVE.md](README_NATIVE.md)

---

## 📄 Лицензия

MIT License — подробности в [LICENSE](LICENSE).

Copyright (c) 2026 SamNet Technologies
