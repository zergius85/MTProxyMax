#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  MTProxyMax Native — Полный установщик
#  Устанавливает все компоненты: движок, скрипт, веб, бот
# ═══════════════════════════════════════════════════════════════
set -eo pipefail

INSTALL_DIR="/opt/mtproxymax"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[i]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1" >&2; }
log_error()   { echo -e "${RED}[✗]${NC} $1" >&2; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Требуется запуск от root"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian|pop|linuxmint|kali) echo "debian" ;;
            centos|rhel|fedora|rocky|alma|oracle) echo "rhel" ;;
            alpine) echo "alpine" ;;
            *) echo "unknown" ;;
        esac
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

install_dependencies() {
    local os
    os=$(detect_os)
    
    log_info "Установка системных зависимостей..."
    
    case "$os" in
        debian)
            apt-get update -qq
            apt-get install -y -qq curl git wget openssl qrencode
            # Python если не установлен
            command -v python3 &>/dev/null || apt-get install -y -qq python3 python3-pip python3-venv
            ;;
        rhel)
            yum install -y -q curl git wget openssl qrencode
            command -v python3 &>/dev/null || yum install -y -q python3 python3-pip
            ;;
        alpine)
            apk add --no-cache curl git wget openssl qrencode
            command -v python3 &>/dev/null || apk add --no-cache python3 py3-pip
            ;;
    esac
    
    log_success "Зависимости установлены"
}

install_engine() {
    log_info "Установка движка telemt..."
    bash "$SCRIPT_DIR/engine/install_engine.sh"
    log_success "Движок установлен"
}

install_script() {
    log_info "Установка скрипта управления..."
    
    mkdir -p "$INSTALL_DIR"
    cp "$SCRIPT_DIR/mtproxymax-native.sh" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/locale.sh" "$INSTALL_DIR/"
    cp -r "$SCRIPT_DIR/locales" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/engine/enginectl.sh" "$INSTALL_DIR/"
    
    chmod +x "$INSTALL_DIR/mtproxymax-native.sh"
    chmod +x "$INSTALL_DIR/enginectl.sh"
    
    # Создаём symlink для удобного запуска
    ln -sf "$INSTALL_DIR/mtproxymax-native.sh" /usr/local/bin/mtproxymax
    
    log_success "Скрипт управления установлен"
}

install_web() {
    log_info "Настройка веб-интерфейса..."
    
    mkdir -p "$INSTALL_DIR/web"
    cp "$SCRIPT_DIR/web/app.py" "$INSTALL_DIR/web/"
    cp "$SCRIPT_DIR/web/requirements.txt" "$INSTALL_DIR/web/"
    cp "$SCRIPT_DIR/web/mtproxymax-web.service" "/etc/systemd/system/"
    
    if [ -d "$SCRIPT_DIR/web/templates" ]; then
        cp -r "$SCRIPT_DIR/web/templates" "$INSTALL_DIR/web/"
    fi
    
    if [ -d "$SCRIPT_DIR/web/static" ]; then
        cp -r "$SCRIPT_DIR/web/static" "$INSTALL_DIR/web/"
    fi
    
    # Виртуальное окружение
    cd "$INSTALL_DIR/web"
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    deactivate
    
    # systemd сервис
    systemctl daemon-reload
    systemctl enable mtproxymax-web
    systemctl start mtproxymax-web
    
    log_success "Веб-интерфейс установлен"
    echo -e "  ${DIM}Доступ: http://YOUR_SERVER_IP:8080${NC}"
}

install_bot() {
    log_info "Настройка Telegram-бота..."
    
    mkdir -p "$INSTALL_DIR/bot"
    cp "$SCRIPT_DIR/bot/bot.py" "$INSTALL_DIR/bot/"
    cp "$SCRIPT_DIR/bot/requirements.txt" "$INSTALL_DIR/bot/"
    cp "$SCRIPT_DIR/bot/mtproxymax-bot.service" "/etc/systemd/system/"
    cp "$SCRIPT_DIR/bot/.env.example" "$INSTALL_DIR/bot/.env.example"
    
    # Виртуальное окружение
    cd "$INSTALL_DIR/bot"
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    deactivate
    
    # systemd сервис (не запускаем пока нет .env)
    systemctl daemon-reload
    systemctl enable mtproxymax-bot
    
    log_success "Telegram-бот установлен"
    echo -e "  ${DIM}Для запуска заполните /opt/mtproxymax/bot/.env${NC}"
}

show_summary() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         MTProxyMax Native — Установка завершена      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}✓ Установленные компоненты:${NC}"
    echo ""
    echo "  📦 Движок telemt:"
    echo -e "     Путь: ${CYAN}/opt/mtproxymax/engine/telemt${NC}"
    echo -e "     Управление: ${CYAN}systemctl status mtproxymax-engine${NC}"
    echo ""
    echo "  📝 Скрипт управления:"
    echo -e "     Команда: ${CYAN}mtproxymax${NC}"
    echo -e "     TUI меню: ${CYAN}sudo mtproxymax menu${NC}"
    echo ""
    echo "  🌐 Веб-интерфейс:"
    echo -e "     Адрес: ${CYAN}http://YOUR_SERVER_IP:8080${NC}"
    echo -e "     Сервис: ${CYAN}systemctl status mtproxymax-web${NC}"
    echo ""
    echo "  🤖 Telegram-бот:"
    echo -e "     Конфиг: ${CYAN}/opt/mtproxymax/bot/.env${NC}"
    echo -e "     Сервис: ${CYAN}systemctl status mtproxymax-bot${NC}"
    echo ""
    echo -e "${YELLOW}📖 Документация:${NC}"
    echo -e "     ${CYAN}/opt/mtproxymax/README_NATIVE.md${NC}"
    echo ""
    echo -e "${BRIGHT_CYAN}Быстрый старт:${NC}"
    echo ""
    echo "  1. Добавьте секрет:"
    echo -e "     ${DIM}sudo mtproxymax secret add myuser${NC}"
    echo ""
    echo "  2. Запустите прокси:"
    echo -e "     ${DIM}sudo mtproxymax start${NC}"
    echo ""
    echo "  3. Проверьте статус:"
    echo -e "     ${DIM}sudo mtproxymax status${NC}"
    echo ""
    echo "  4. Для Telegram-бота:"
    echo -e "     ${DIM}nano /opt/mtproxymax/bot/.env${NC}"
    echo -e "     ${DIM}systemctl start mtproxymax-bot${NC}"
    echo ""
}

# Main
main() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║       MTProxyMax Native — Установщик                 ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_root
    
    echo -e "${YELLOW}Компоненты для установки:${NC}"
    echo "  [1] Движок telemt"
    echo "  [2] Скрипт управления"
    echo "  [3] Веб-интерфейс"
    echo "  [4] Telegram-бот"
    echo "  [5] Всё сразу"
    echo "  [0] Выход"
    echo ""
    
    read -p "Выберите компонент: " choice
    
    case "$choice" in
        1)
            install_dependencies
            install_engine
            ;;
        2)
            install_dependencies
            install_script
            ;;
        3)
            install_dependencies
            install_web
            ;;
        4)
            install_dependencies
            install_bot
            ;;
        5)
            install_dependencies
            install_engine
            install_script
            install_web
            install_bot
            show_summary
            ;;
        0)
            echo -e "\n${CYAN}Установка отменена${NC}"
            exit 0
            ;;
        *)
            log_error "Неверный выбор"
            exit 1
            ;;
    esac
}

main "$@"
