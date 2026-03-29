#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  Управление движком telemt (без Docker)
# ═══════════════════════════════════════════════════════════════

ENGINE_DIR="/opt/mtproxymax/engine"
ENGINE_BIN="$ENGINE_DIR/telemt"
ENGINE_SERVICE="mtproxymax-engine"
CONFIG_DIR="/opt/mtproxymax/mtproxy"
CONFIG_FILE="$CONFIG_DIR/config.toml"
PID_FILE="/run/mtproxymax.pid"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[i]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error()   { echo -e "${RED}[✗]${NC} $1" >&2; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Требуется запуск от root"
        exit 1
    fi
}

engine_installed() {
    [ -x "$ENGINE_BIN" ]
}

get_version() {
    if [ -f "$ENGINE_DIR/.version" ]; then
        cat "$ENGINE_DIR/.version"
    elif [ -x "$ENGINE_BIN" ]; then
        "$ENGINE_BIN" --version 2>/dev/null | head -1 || echo "unknown"
    else
        echo "not installed"
    fi
}

is_running() {
    if systemctl is-active --quiet "$ENGINE_SERVICE" 2>/dev/null; then
        return 0
    fi
    # Fallback: check PID file
    if [ -f "$PID_FILE" ]; then
        kill -0 "$(cat "$PID_FILE")" 2>/dev/null
        return $?
    fi
    return 1
}

start() {
    check_root
    
    if ! engine_installed; then
        log_error "Движок не установлен"
        exit 1
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Конфигурация не найдена: $CONFIG_FILE"
        exit 1
    fi
    
    if is_running; then
        log_info "Движок уже запущен"
        return 0
    fi
    
    log_info "Запуск движка..."
    
    # Пробуем через systemd
    if command -v systemctl &>/dev/null; then
        systemctl start "$ENGINE_SERVICE" 2>/dev/null && {
            sleep 2
            if is_running; then
                log_success "Движок запущен через systemd"
                return 0
            fi
        }
    fi
    
    # Fallback: прямой запуск
    log_info "Прямой запуск (без systemd)..."
    mkdir -p "$(dirname "$PID_FILE")"
    nohup "$ENGINE_BIN" "$CONFIG_FILE" > /var/log/mtproxymax-engine.log 2>&1 &
    echo $! > "$PID_FILE"
    
    sleep 2
    if kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
        log_success "Движок запущен (PID: $(cat "$PID_FILE"))"
        return 0
    else
        log_error "Не удалось запустить движок"
        return 1
    fi
}

stop() {
    check_root
    
    if ! is_running; then
        log_info "Движок не запущен"
        return 0
    fi
    
    log_info "Остановка движка..."
    
    if command -v systemctl &>/dev/null && systemctl is-active --quiet "$ENGINE_SERVICE" 2>/dev/null; then
        systemctl stop "$ENGINE_SERVICE"
        log_success "Движок остановлен"
        return 0
    fi
    
    # Fallback: kill через PID
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid"
            sleep 2
            if ! kill -0 "$pid" 2>/dev/null; then
                log_success "Движок остановлен"
                rm -f "$PID_FILE"
                return 0
            fi
            # Force kill
            kill -9 "$pid" 2>/dev/null
            log_success "Движок принудительно остановлен"
            rm -f "$PID_FILE"
            return 0
        fi
    fi
    
    # Last resort: pkill
    pkill -f "telemt.*config.toml" 2>/dev/null && {
        log_success "Движок остановлен"
        return 0
    }
    
    log_warn "Не удалось найти процесс движка"
    return 1
}

restart() {
    stop
    sleep 1
    start
}

status() {
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  MTProxyMax Engine Status              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    local version
    version=$(get_version)
    echo -e "  Версия:     ${YELLOW}${version}${NC}"
    
    echo -e "  Бинарник:   ${YELLOW}${ENGINE_BIN}${NC}"
    if [ -x "$ENGINE_BIN" ]; then
        echo -e "              ${GREEN}✓ установлен${NC}"
    else
        echo -e "              ${RED}✗ не найден${NC}"
    fi
    
    echo ""
    echo -e "  Статус:     $(is_running && echo -e "${GREEN}● запущен${NC}" || echo -e "${RED}● остановлен${NC}")"
    
    if is_running; then
        local pid=""
        if [ -f "$PID_FILE" ]; then
            pid=$(cat "$PID_FILE")
        fi
        if [ -z "$pid" ]; then
            pid=$(pgrep -f "telemt.*config.toml" | head -1)
        fi
        [ -n "$pid" ] && echo -e "  PID:        ${YELLOW}${pid}${NC}"
    fi
    
    echo ""
    echo -e "  Конфиг:     ${YELLOW}${CONFIG_FILE}${NC}"
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "              ${GREEN}✓ существует${NC}"
    else
        echo -e "              ${RED}✗ не найден${NC}"
    fi
    
    echo ""
    
    if command -v systemctl &>/dev/null; then
        echo -e "  ${DIM}Systemd сервис: ${ENGINE_SERVICE}${NC}"
        systemctl is-active --quiet "$ENGINE_SERVICE" 2>/dev/null && \
            echo -e "  ${DIM}              активен${NC}" || \
            echo -e "  ${DIM}              не активен${NC}"
        echo ""
    fi
}

logs() {
    local follow="${1:-false}"
    
    if [ -f /var/log/mtproxymax-engine.log ]; then
        if [ "$follow" = "true" ] || [ "$follow" = "-f" ]; then
            tail -f /var/log/mtproxymax-engine.log
        else
            tail -100 /var/log/mtproxymax-engine.log
        fi
        return 0
    fi
    
    if command -v journalctl &>/dev/null; then
        if [ "$follow" = "true" ] || [ "$follow" = "-f" ]; then
            journalctl -u "$ENGINE_SERVICE" -f --no-pager
        else
            journalctl -u "$ENGINE_SERVICE" --no-pager -n 50
        fi
        return 0
    fi
    
    log_error "Логи не найдены"
    return 1
}

rebuild() {
    check_root
    
    log_info "Пересборка движка..."
    
    local src_dir="$ENGINE_DIR/src"
    
    if [ -d "$src_dir" ]; then
        cd "$src_dir"
        git pull
        cargo build --release
        cp "target/release/telemt" "$ENGINE_BIN"
        chmod +x "$ENGINE_BIN"
        log_success "Пересборка завершена"
        restart
    else
        log_error "Исходники не найдены"
        exit 1
    fi
}

show_help() {
    echo -e "${CYAN}Управление движком MTProxyMax (telemt)${NC}"
    echo ""
    echo "Использование: $0 <команда>"
    echo ""
    echo "Команды:"
    echo "  start       Запустить движок"
    echo "  stop        Остановить движок"
    echo "  restart     Перезапустить движок"
    echo "  status      Показать статус"
    echo "  logs [-f]   Показать логи (с -f для режима follow)"
    echo "  rebuild     Пересобрать из исходников"
    echo "  version     Показать версию"
    echo "  help        Эта справка"
    echo ""
}

# Main
case "${1:-status}" in
    start)   start ;;
    stop)    stop ;;
    restart) restart ;;
    status)  status ;;
    logs)    logs "${2:-false}" ;;
    rebuild) rebuild ;;
    version) get_version ;;
    help|--help|-h) show_help ;;
    *)
        log_error "Неизвестная команда: $1"
        show_help
        exit 1
        ;;
esac
