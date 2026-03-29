#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  MTProxyMax Native — The Ultimate Telegram Proxy Manager
#  Версия без Docker (локальный запуск telemt)
#  Copyright (c) 2026 SamNet Technologies
# ═══════════════════════════════════════════════════════════════
set -eo pipefail
export LC_NUMERIC=C

VERSION="1.0.4-native"
SCRIPT_NAME="mtproxymax"
INSTALL_DIR="/opt/mtproxymax"
CONFIG_DIR="${INSTALL_DIR}/mtproxy"
SETTINGS_FILE="${INSTALL_DIR}/settings.conf"
SECRETS_FILE="${INSTALL_DIR}/secrets.conf"
STATS_DIR="${INSTALL_DIR}/relay_stats"
UPSTREAMS_FILE="${INSTALL_DIR}/upstreams.conf"
BACKUP_DIR="${INSTALL_DIR}/backups"
INSTANCES_FILE="${INSTALL_DIR}/instances.conf"

# Engine (без Docker)
ENGINE_DIR="/opt/mtproxymax/engine"
ENGINE_BIN="$ENGINE_DIR/telemt"
ENGINE_PID_FILE="/run/mtproxymax.pid"
TELEMT_MIN_VERSION="3.3.32"

GITHUB_REPO="SamNet-dev/MTProxyMax"

# Проверка версии Bash
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
    echo "ERROR: MTProxyMax требует bash 4.2+. У вас: ${BASH_VERSION:-unknown}" >&2
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
# Цвета
# ═══════════════════════════════════════════════════════════════
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

readonly BRIGHT_GREEN='\033[1;32m'
readonly BRIGHT_CYAN='\033[1;36m'
readonly BRIGHT_YELLOW='\033[1;33m'
readonly BRIGHT_RED='\033[1;31m'
readonly BRIGHT_MAGENTA='\033[1;35m'
readonly BRIGHT_WHITE='\033[1;37m'

# Box drawing
readonly BOX_TL='┌' BOX_TR='┐' BOX_BL='└' BOX_BR='┘'
readonly BOX_H='─' BOX_V='│'

# Status symbols
readonly SYM_OK='●'
readonly SYM_ARROW='►'
readonly SYM_CHECK='✓'
readonly SYM_CROSS='✗'
readonly SYM_WARN='!'

# Конфигурация по умолчанию
PROXY_PORT=443
PROXY_METRICS_PORT=9090
PROXY_DOMAIN="cloudflare.com"
PROXY_CONCURRENCY=8192
CUSTOM_IP=""
FAKE_CERT_LEN=2048
PROXY_PROTOCOL="false"
AD_TAG=""
GEOBLOCK_MODE="blacklist"
BLOCKLIST_COUNTRIES=""
MASKING_ENABLED="true"
MASKING_HOST=""
MASKING_PORT=443
UNKNOWN_SNI_ACTION="mask"

# Массивы для данных
declare -a SECRETS_LABELS=()
declare -a SECRETS_KEYS=()
declare -a SECRETS_CREATED=()
declare -a SECRETS_ENABLED=()
declare -a SECRETS_MAX_CONNS=()
declare -a SECRETS_MAX_IPS=()
declare -a SECRETS_QUOTA=()
declare -a SECRETS_EXPIRES=()
declare -a SECRETS_NOTES=()

declare -a UPSTREAM_NAMES=()
declare -a UPSTREAM_TYPES=()
declare -a UPSTREAM_ADDRS=()
declare -a UPSTREAM_USERS=()
declare -a UPSTREAM_PASSES=()
declare -a UPSTREAM_WEIGHTS=()
declare -a UPSTREAM_IFACES=()
declare -a UPSTREAM_ENABLED=()

# ═══════════════════════════════════════════════════════════════
# Утилиты
# ═══════════════════════════════════════════════════════════════
log_info()    { echo -e "${BLUE}[i]${NC} $1"; }
log_success() { echo -e "${GREEN}[${SYM_CHECK}]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[${SYM_WARN}]${NC} $1" >&2; }
log_error()   { echo -e "${RED}[${SYM_CROSS}]${NC} $1" >&2; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Требуется запуск от root"
        echo -e "  ${DIM}Попробуйте: sudo $0 $*${NC}"
        exit 1
    fi
}

get_public_ip() {
    if [ -n "$CUSTOM_IP" ]; then
        echo "$CUSTOM_IP"
        return 0
    fi
    local ip=""
    ip=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null) ||
    ip=$(curl -s --max-time 3 https://ifconfig.me 2>/dev/null) ||
    ip=$(curl -s --max-time 3 https://icanhazip.com 2>/dev/null) ||
    ip=""
    echo "$ip"
}

validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
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

# ═══════════════════════════════════════════════════════════════
# Загрузка/сохранение настроек
# ═══════════════════════════════════════════════════════════════
load_settings() {
    [ -f "$SETTINGS_FILE" ] || return 0

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        if [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=\'([^\']*)\'$ ]]; then
            local key="${BASH_REMATCH[1]}" val="${BASH_REMATCH[2]}"
        elif [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=\"([^\"]*)\"$ ]]; then
            local key="${BASH_REMATCH[1]}" val="${BASH_REMATCH[2]}"
        elif [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=([^[:space:]]*)$ ]]; then
            local key="${BASH_REMATCH[1]}" val="${BASH_REMATCH[2]}"
        else
            continue
        fi

        case "$key" in
            PROXY_PORT|PROXY_METRICS_PORT|PROXY_DOMAIN|PROXY_CONCURRENCY|\
            CUSTOM_IP|FAKE_CERT_LEN|PROXY_PROTOCOL|AD_TAG|GEOBLOCK_MODE|BLOCKLIST_COUNTRIES|\
            MASKING_ENABLED|MASKING_HOST|MASKING_PORT|UNKNOWN_SNI_ACTION)
                printf -v "$key" '%s' "$val"
                ;;
        esac
    done < "$SETTINGS_FILE"

    # Валидация
    [[ "$PROXY_PORT" =~ ^[0-9]+$ ]] && [ "$PROXY_PORT" -ge 1 ] && [ "$PROXY_PORT" -le 65535 ] || PROXY_PORT=443
    [[ "$PROXY_METRICS_PORT" =~ ^[0-9]+$ ]] && [ "$PROXY_METRICS_PORT" -ge 1 ] && [ "$PROXY_METRICS_PORT" -le 65535 ] || PROXY_METRICS_PORT=9090
    [[ "$PROXY_PROTOCOL" == "true" ]] || PROXY_PROTOCOL="false"
    [[ "$UNKNOWN_SNI_ACTION" == "drop" ]] || UNKNOWN_SNI_ACTION="mask"
}

save_settings() {
    mkdir -p "$INSTALL_DIR"
    cat > "$SETTINGS_FILE" << EOF
# MTProxyMax Settings — v${VERSION}
PROXY_PORT='${PROXY_PORT}'
PROXY_METRICS_PORT='${PROXY_METRICS_PORT}'
PROXY_DOMAIN='${PROXY_DOMAIN}'
PROXY_CONCURRENCY='${PROXY_CONCURRENCY}'
CUSTOM_IP='${CUSTOM_IP}'
FAKE_CERT_LEN='${FAKE_CERT_LEN}'
PROXY_PROTOCOL='${PROXY_PROTOCOL}'
AD_TAG='${AD_TAG}'
GEOBLOCK_MODE='${GEOBLOCK_MODE}'
BLOCKLIST_COUNTRIES='${BLOCKLIST_COUNTRIES}'
MASKING_ENABLED='${MASKING_ENABLED}'
MASKING_HOST='${MASKING_HOST}'
MASKING_PORT='${MASKING_PORT}'
UNKNOWN_SNI_ACTION='${UNKNOWN_SNI_ACTION}'
EOF
    chmod 600 "$SETTINGS_FILE"
}

# ═══════════════════════════════════════════════════════════════
# Управление секретами
# ═══════════════════════════════════════════════════════════════
load_secrets() {
    SECRETS_LABELS=()
    SECRETS_KEYS=()
    SECRETS_CREATED=()
    SECRETS_ENABLED=()
    SECRETS_MAX_CONNS=()
    SECRETS_MAX_IPS=()
    SECRETS_QUOTA=()
    SECRETS_EXPIRES=()
    SECRETS_NOTES=()

    if [ -f "$SECRETS_FILE" ]; then
        while IFS='|' read -r label secret created enabled max_conns max_ips quota expires notes; do
            [[ "$label" =~ ^[[:space:]]*# ]] && continue
            [[ "$label" =~ ^[[:space:]]*$ ]] && continue
            [ -z "$secret" ] && continue
            [[ "$label" =~ ^[a-zA-Z0-9_-]+$ ]] || continue
            [[ "$secret" =~ ^[0-9a-fA-F]{32}$ ]] || continue

            SECRETS_LABELS+=("$label")
            SECRETS_KEYS+=("$secret")
            SECRETS_CREATED+=("${created:-$(date +%s)}")
            SECRETS_ENABLED+=("${enabled:-true}")
            SECRETS_MAX_CONNS+=("${max_conns:-0}")
            SECRETS_MAX_IPS+=("${max_ips:-0}")
            SECRETS_QUOTA+=("${quota:-0}")
            SECRETS_EXPIRES+=("${expires:-0}")
            SECRETS_NOTES+=("${notes:-}")
        done < "$SECRETS_FILE"
    fi
}

save_secrets() {
    mkdir -p "$INSTALL_DIR"
    local tmp=$(mktemp)
    
    echo "# MTProxyMax Secrets Database — v${VERSION}" > "$tmp"
    echo "# Format: LABEL|SECRET|CREATED_TS|ENABLED|MAX_CONNS|MAX_IPS|QUOTA_BYTES|EXPIRES|NOTES" >> "$tmp"

    for i in "${!SECRETS_LABELS[@]}"; do
        echo "${SECRETS_LABELS[$i]}|${SECRETS_KEYS[$i]}|${SECRETS_CREATED[$i]}|${SECRETS_ENABLED[$i]}|${SECRETS_MAX_CONNS[$i]:-0}|${SECRETS_MAX_IPS[$i]:-0}|${SECRETS_QUOTA[$i]:-0}|${SECRETS_EXPIRES[$i]:-0}|${SECRETS_NOTES[$i]:-}" >> "$tmp"
    done

    chmod 600 "$tmp"
    mv "$tmp" "$SECRETS_FILE"
}

generate_secret() {
    openssl rand -hex 16
}

secret_add() {
    local label="$1"
    
    if [ -z "$label" ]; then
        log_error "Укажите имя секрета"
        return 1
    fi
    
    # Проверка на дубликат
    for existing in "${SECRETS_LABELS[@]}"; do
        if [ "$existing" = "$label" ]; then
            log_error "Секрет с именем '$label' уже существует"
            return 1
        fi
    done
    
    local secret
    secret=$(generate_secret)
    local created
    created=$(date +%s)
    
    SECRETS_LABELS+=("$label")
    SECRETS_KEYS+=("$secret")
    SECRETS_CREATED+=("$created")
    SECRETS_ENABLED+=("true")
    SECRETS_MAX_CONNS+=("0")
    SECRETS_MAX_IPS+=("0")
    SECRETS_QUOTA+=("0")
    SECRETS_EXPIRES+=("0")
    SECRETS_NOTES+=("")
    
    save_secrets
    
    log_success "Секрет '$label' добавлен"
    echo ""
    echo -e "  ${DIM}Ключ:${NC} ${CYAN}${secret}${NC}"
    echo -e "  ${DIM}Ссылка:${NC} $(get_proxy_link "$label")"
    echo ""
}

secret_list() {
    if [ ${#SECRETS_LABELS[@]} -eq 0 ]; then
        log_info "Секретов нет"
        return 0
    fi
    
    echo ""
    echo -e "${BOLD}  %-20s %-10s %-8s %-12s %-10s${NC}" "Имя" "Статус" "Устр." "Трафик" "Истекает"
    echo -e "  $(printf '─%.0s' {1..70})"
    
    for i in "${!SECRETS_LABELS[@]}"; do
        local status="${SECRETS_ENABLED[$i]}"
        local status_text="активен"
        [ "$status" != "true" ] && status_text="отключен"
        local status_color="$GREEN"
        [ "$status" != "true" ] && status_color="$RED"
        
        local conns="${SECRETS_MAX_CONNS[$i]}"
        [ "$conns" = "0" ] && conns="∞"
        
        local quota="${SECRETS_QUOTA[$i]}"
        local quota_text="-"
        if [ "$quota" != "0" ]; then
            quota_text=$(format_bytes "$quota")
        fi
        
        local expires="${SECRETS_EXPIRES[$i]}"
        local expires_text="-"
        if [ "$expires" != "0" ] && [ -n "$expires" ]; then
            expires_text="$expires"
        fi
        
        printf "  ${status_color}%-20s %-10s %-8s %-12s %-10s${NC}\n" \
            "${SECRETS_LABELS[$i]}" "$status_text" "$conns" "$quota_text" "$expires_text"
    done
    echo ""
}

secret_remove() {
    local label="$1"
    local found=-1
    
    for i in "${!SECRETS_LABELS[@]}"; do
        if [ "${SECRETS_LABELS[$i]}" = "$label" ]; then
            found=$i
            break
        fi
    done
    
    if [ $found -eq -1 ]; then
        log_error "Секрет '$label' не найден"
        return 1
    fi
    
    SECRETS_LABELS=("${SECRETS_LABELS[@]:0:$found}" "${SECRETS_LABELS[@]:$((found+1))}")
    SECRETS_KEYS=("${SECRETS_KEYS[@]:0:$found}" "${SECRETS_KEYS[@]:$((found+1))}")
    SECRETS_CREATED=("${SECRETS_CREATED[@]:0:$found}" "${SECRETS_CREATED[@]:$((found+1))}")
    SECRETS_ENABLED=("${SECRETS_ENABLED[@]:0:$found}" "${SECRETS_ENABLED[@]:$((found+1))}")
    SECRETS_MAX_CONNS=("${SECRETS_MAX_CONNS[@]:0:$found}" "${SECRETS_MAX_CONNS[@]:$((found+1))}")
    SECRETS_MAX_IPS=("${SECRETS_MAX_IPS[@]:0:$found}" "${SECRETS_MAX_IPS[@]:$((found+1))}")
    SECRETS_QUOTA=("${SECRETS_QUOTA[@]:0:$found}" "${SECRETS_QUOTA[@]:$((found+1))}")
    SECRETS_EXPIRES=("${SECRETS_EXPIRES[@]:0:$found}" "${SECRETS_EXPIRES[@]:$((found+1))}")
    SECRETS_NOTES=("${SECRETS_NOTES[@]:0:$found}" "${SECRETS_NOTES[@]:$((found+1))}")
    
    save_secrets
    log_success "Секрет '$label' удалён"
}

secret_enable() {
    local label="$1"
    for i in "${!SECRETS_LABELS[@]}"; do
        if [ "${SECRETS_LABELS[$i]}" = "$label" ]; then
            SECRETS_ENABLED[$i]="true"
            save_secrets
            log_success "Секрет '$label' включён"
            return 0
        fi
    done
    log_error "Секрет '$label' не найден"
}

secret_disable() {
    local label="$1"
    for i in "${!SECRETS_LABELS[@]}"; do
        if [ "${SECRETS_LABELS[$i]}" = "$label" ]; then
            SECRETS_ENABLED[$i]="false"
            save_secrets
            log_success "Секрет '$label' отключён"
            return 0
        fi
    done
    log_error "Секрет '$label' не найден"
}

secret_rotate() {
    local label="$1"
    for i in "${!SECRETS_LABELS[@]}"; do
        if [ "${SECRETS_LABELS[$i]}" = "$label" ]; then
            SECRETS_KEYS[$i]=$(generate_secret)
            SECRETS_CREATED[$i]=$(date +%s)
            save_secrets
            log_success "Секрет '$label' обновлён"
            echo -e "  ${DIM}Новый ключ:${NC} ${CYAN}${SECRETS_KEYS[$i]}${NC}"
            return 0
        fi
    done
    log_error "Секрет '$label' не найден"
}

secret_setlimit() {
    local label="$1"
    local limit_type="$2"
    local value="$3"
    
    for i in "${!SECRETS_LABELS[@]}"; do
        if [ "${SECRETS_LABELS[$i]}" = "$label" ]; then
            case "$limit_type" in
                conns) SECRETS_MAX_CONNS[$i]="$value" ;;
                ips) SECRETS_MAX_IPS[$i]="$value" ;;
                quota) 
                    local bytes
                    bytes=$(parse_human_bytes "$value")
                    SECRETS_QUOTA[$i]="$bytes"
                    ;;
                expires) SECRETS_EXPIRES[$i]="$value" ;;
                *)
                    log_error "Неизвестный тип лимита: $limit_type"
                    return 1
                    ;;
            esac
            save_secrets
            log_success "Лимит установлен для '$label'"
            return 0
        fi
    done
    log_error "Секрет '$label' не найден"
}

# ═══════════════════════════════════════════════════════════════
# Форматирование
# ═══════════════════════════════════════════════════════════════
format_bytes() {
    local bytes=$1
    [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0
    if [ -z "$bytes" ] || [ "$bytes" = "0" ]; then
        echo "0 B"
        return
    fi
    if [ "$bytes" -lt 1024 ] 2>/dev/null; then
        echo "${bytes} B"
    elif [ "$bytes" -lt 1048576 ] 2>/dev/null; then
        echo "$(awk -v b="$bytes" 'BEGIN {printf "%.1f", b/1024}') KB"
    elif [ "$bytes" -lt 1073741824 ] 2>/dev/null; then
        echo "$(awk -v b="$bytes" 'BEGIN {printf "%.2f", b/1048576}') MB"
    else
        echo "$(awk -v b="$bytes" 'BEGIN {printf "%.2f", b/1073741824}') GB"
    fi
}

parse_human_bytes() {
    local input="${1:-0}"
    input="${input^^}"
    local num unit
    if [[ "$input" =~ ^([0-9]+(\.[0-9]+)?)[[:space:]]*(B|K|KB|M|MB|G|GB|T|TB)?$ ]]; then
        num="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[3]:-B}"
    elif [[ "$input" =~ ^[0-9]+$ ]]; then
        echo "$input"
        return 0
    else
        echo "0"
        return 1
    fi
    case "$unit" in
        B)        awk -v n="$num" 'BEGIN {printf "%d", n}' ;;
        K|KB)     awk -v n="$num" 'BEGIN {printf "%d", n * 1024}' ;;
        M|MB)     awk -v n="$num" 'BEGIN {printf "%d", n * 1048576}' ;;
        G|GB)     awk -v n="$num" 'BEGIN {printf "%d", n * 1073741824}' ;;
        T|TB)     awk -v n="$num" 'BEGIN {printf "%d", n * 1099511627776}' ;;
        *)        echo "0"; return 1 ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
# Ссылки и QR
# ═══════════════════════════════════════════════════════════════
build_faketls_secret() {
    local secret="$1"
    local domain="${PROXY_DOMAIN:-cloudflare.com}"
    local domain_hex
    domain_hex=$(echo -n "$domain" | xxd -p | tr -d '\n')
    echo "ee${secret}${domain_hex}"
}

get_proxy_link() {
    local label="$1"
    local secret_key=""
    
    for i in "${!SECRETS_LABELS[@]}"; do
        if [ "${SECRETS_LABELS[$i]}" = "$label" ]; then
            secret_key="${SECRETS_KEYS[$i]}"
            break
        fi
    done
    
    if [ -z "$secret_key" ]; then
        echo ""
        return 1
    fi
    
    local server_ip
    server_ip=$(get_public_ip)
    [ -z "$server_ip" ] && server_ip="YOUR_SERVER_IP"
    
    local full_secret
    full_secret=$(build_faketls_secret "$secret_key")
    
    echo "tg://proxy?server=${server_ip}&port=${PROXY_PORT}&secret=${full_secret}"
}

show_qr() {
    local label="$1"
    local link
    link=$(get_proxy_link "$label")
    
    if [ -z "$link" ]; then
        log_error "Секрет не найден"
        return 1
    fi
    
    if command -v qrencode &>/dev/null; then
        qrencode -t ANSIUTF8 "$link"
    else
        log_warn "qrencode не установлен"
        echo -e "  ${DIM}Ссылка:${NC} $link"
    fi
}

# ═══════════════════════════════════════════════════════════════
# Генерация конфига telemt
# ═══════════════════════════════════════════════════════════════
generate_telemt_config() {
    mkdir -p "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR"

    local domain="${PROXY_DOMAIN:-cloudflare.com}"
    local mask_host="${MASKING_HOST:-$domain}"
    local mask_port="${MASKING_PORT:-443}"
    local ad_tag="${AD_TAG:-}"
    local port="${PROXY_PORT:-443}"
    local metrics_port="${PROXY_METRICS_PORT:-9090}"

    local tmp=$(mktemp)

    cat > "$tmp" << EOF
# MTProxyMax — telemt configuration
# Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

[general]
prefer_ipv6 = false
fast_mode = true
use_middle_proxy = true
log_level = "normal"
$([ -n "$ad_tag" ] && echo "ad_tag = \"$ad_tag\"")

[general.modes]
classic = false
secure = false
tls = true

[general.links]
show = [$(get_enabled_labels_quoted)]

[server]
port = ${port}
listen_addr_ipv4 = "0.0.0.0"
listen_addr_ipv6 = "::"
proxy_protocol = ${PROXY_PROTOCOL:-false}
metrics_port = ${metrics_port}
metrics_whitelist = ["127.0.0.1", "::1"]

[timeouts]
client_handshake = 30
tg_connect = 10
client_keepalive = 15
client_ack = 90

[censorship]
tls_domain = "${domain}"
unknown_sni_action = "${UNKNOWN_SNI_ACTION:-mask}"
mask = ${mask_enabled:-true}
mask_port = ${mask_port}
$([ "$mask_enabled" = "true" ] && [ -n "$mask_host" ] && echo "mask_host = \"${mask_host}\"")
fake_cert_len = ${FAKE_CERT_LEN:-2048}

[access]
replay_check_len = 65536
replay_window_secs = 1800
ignore_time_skew = false

[access.users]
EOF

    for i in "${!SECRETS_LABELS[@]}"; do
        [ "${SECRETS_ENABLED[$i]}" = "true" ] || continue
        echo "${SECRETS_LABELS[$i]} = \"${SECRETS_KEYS[$i]}\"" >> "$tmp"
    done

    # Лимиты
    local has_conns=false
    for i in "${!SECRETS_LABELS[@]}"; do
        [ "${SECRETS_ENABLED[$i]}" = "true" ] && [ "${SECRETS_MAX_CONNS[$i]:-0}" != "0" ] && has_conns=true
    done

    if $has_conns; then
        echo "" >> "$tmp"
        echo "[access.user_max_tcp_conns]" >> "$tmp"
        for i in "${!SECRETS_LABELS[@]}"; do
            [ "${SECRETS_ENABLED[$i]}" = "true" ] && [ "${SECRETS_MAX_CONNS[$i]:-0}" != "0" ] || continue
            echo "${SECRETS_LABELS[$i]} = ${SECRETS_MAX_CONNS[$i]}" >> "$tmp"
        done
    fi

    chmod 644 "$tmp"
    mv "$tmp" "${CONFIG_DIR}/config.toml"
}

get_enabled_labels_quoted() {
    local result="" first=true
    for i in "${!SECRETS_LABELS[@]}"; do
        [ "${SECRETS_ENABLED[$i]}" = "true" ] || continue
        if $first; then
            result="\"${SECRETS_LABELS[$i]}\""
            first=false
        else
            result+=", \"${SECRETS_LABELS[$i]}\""
        fi
    done
    echo "$result"
}

# ═══════════════════════════════════════════════════════════════
# Управление движком
# ═══════════════════════════════════════════════════════════════
engine_installed() {
    [ -x "$ENGINE_BIN" ]
}

get_engine_version() {
    if [ -f "$ENGINE_DIR/.version" ]; then
        cat "$ENGINE_DIR/.version"
    elif [ -x "$ENGINE_BIN" ]; then
        "$ENGINE_BIN" --version 2>/dev/null | head -1 || echo "unknown"
    else
        echo "not installed"
    fi
}

is_engine_running() {
    if [ -f "$ENGINE_PID_FILE" ]; then
        kill -0 "$(cat "$ENGINE_PID_FILE")" 2>/dev/null
        return $?
    fi
    pgrep -f "telemt.*config.toml" &>/dev/null
    return $?
}

start_engine() {
    if ! engine_installed; then
        log_error "Движок не установлен"
        echo -e "  ${DIM}Установите: bash engine/install_engine.sh${NC}"
        return 1
    fi

    if [ ! -f "${CONFIG_DIR}/config.toml" ]; then
        generate_telemt_config
    fi

    if is_engine_running; then
        log_info "Движок уже запущен"
        return 0
    fi

    log_info "Запуск telemt..."

    # Проверка лимитов
    local current_limit
    current_limit=$(ulimit -n 2>/dev/null || echo "1024")
    if [ "$current_limit" -lt 65536 ]; then
        ulimit -n 65536 2>/dev/null || log_warn "Не удалось увеличить ulimit -n (текущий: $current_limit)"
    fi

    # Запуск
    nohup "$ENGINE_BIN" "${CONFIG_DIR}/config.toml" > /var/log/mtproxymax.log 2>&1 &
    echo $! > "$ENGINE_PID_FILE"
    
    sleep 2

    if is_engine_running; then
        log_success "telemt запущен (PID: $(cat "$ENGINE_PID_FILE"))"
        return 0
    else
        log_error "Не удалось запустить telemt"
        return 1
    fi
}

stop_engine() {
    if ! is_engine_running; then
        log_info "Движок не запущен"
        return 0
    fi

    log_info "Остановка telemt..."

    if [ -f "$ENGINE_PID_FILE" ]; then
        local pid
        pid=$(cat "$ENGINE_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid"
            sleep 2
            if ! kill -0 "$pid" 2>/dev/null; then
                log_success "telemt остановлен"
                rm -f "$ENGINE_PID_FILE"
                return 0
            fi
            kill -9 "$pid" 2>/dev/null
            log_success "telemt принудительно остановлен"
            rm -f "$ENGINE_PID_FILE"
            return 0
        fi
    fi

    pkill -f "telemt.*config.toml" 2>/dev/null && {
        log_success "telemt остановлен"
        return 0
    }

    log_warn "Не удалось найти процесс telemt"
    return 1
}

restart_engine() {
    stop_engine
    sleep 1
    start_engine
}

engine_status() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  MTProxyMax Engine Status              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    local version
    version=$(get_engine_version)
    echo -e "  Версия:     ${YELLOW}${version}${NC}"
    
    echo -e "  Бинарник:   ${YELLOW}${ENGINE_BIN}${NC}"
    if [ -x "$ENGINE_BIN" ]; then
        echo -e "              ${GREEN}✓ установлен${NC}"
    else
        echo -e "              ${RED}✗ не найден${NC}"
    fi
    
    echo ""
    local status_text="остановлен"
    local status_color="$RED"
    if is_engine_running; then
        status_text="запущен"
        status_color="$GREEN"
    fi
    echo -e "  Статус:     ${status_color}${status_text}${NC}"
    
    if is_engine_running && [ -f "$ENGINE_PID_FILE" ]; then
        echo -e "  PID:        ${YELLOW}$(cat "$ENGINE_PID_FILE")${NC}"
    fi
    
    echo ""
    echo -e "  Порт:       ${YELLOW}${PROXY_PORT}${NC}"
    echo -e "  Домен:      ${YELLOW}${PROXY_DOMAIN}${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# TUI — Главное меню
# ═══════════════════════════════════════════════════════════════
show_main_menu() {
    clear
    echo -e "${BRIGHT_CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║         MTProxyMax Native — Управление прокси         ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    engine_status
    
    echo -e "  ${BRIGHT_CYAN}${SYM_ARROW}${NC} ${BOLD}Главное меню${NC}"
    echo -e "  ${DIM}─────────────────${NC}"
    echo ""
    echo -e "  [1] Статус прокси"
    echo -e "  [2] Управление секретами"
    echo -e "  [3] Запустить прокси"
    echo -e "  [4] Остановить прокси"
    echo -e "  [5] Перезапустить прокси"
    echo -e "  [6] Настройки"
    echo -e "  [7] Логи"
    echo -e "  [8] Обновить движок"
    echo -e "  [0] Выход"
    echo ""
}

show_secrets_menu() {
    while true; do
        clear
        echo -e "${BRIGHT_CYAN}${BOLD}"
        echo "╔═══════════════════════════════════════════════════════╗"
        echo "║              Управление секретами                     ║"
        echo "╚═══════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        secret_list
        
        echo -e "  ${BRIGHT_CYAN}${SYM_ARROW}${NC} ${BOLD}Меню${NC}"
        echo -e "  ${DIM}─────────────────${NC}"
        echo ""
        echo -e "  [1] Добавить секрет"
        echo -e "  [2] Удалить секрет"
        echo -e "  [3] Включить/Отключить"
        echo -e "  [4] Обновить секрет (rotate)"
        echo -e "  [5] Установить лимиты"
        echo -e "  [6] Показать ссылку"
        echo -e "  [7] Показать QR"
        echo -e "  [0] Назад"
        echo ""
        
        local choice
        read -p "  Выбор: " choice
        
        case "$choice" in
            1)
                read -p "  Введите имя секрета: " label
                secret_add "$label"
                press_any_key
                ;;
            2)
                read -p "  Введите имя секрета: " label
                secret_remove "$label"
                press_any_key
                ;;
            3)
                read -p "  Введите имя секрета: " label
                read -p "  Включить (1) или Отключить (0): " action
                if [ "$action" = "1" ]; then
                    secret_enable "$label"
                else
                    secret_disable "$label"
                fi
                press_any_key
                ;;
            4)
                read -p "  Введите имя секрета: " label
                secret_rotate "$label"
                press_any_key
                ;;
            5)
                read -p "  Введите имя секрета: " label
                echo "  Типы лимитов: conns, ips, quota, expires"
                read -p "  Тип лимита: " limit_type
                read -p "  Значение: " value
                secret_setlimit "$label" "$limit_type" "$value"
                press_any_key
                ;;
            6)
                read -p "  Введите имя секрета: " label
                echo ""
                echo -e "  ${DIM}Ссылка:${NC} $(get_proxy_link "$label")"
                echo ""
                press_any_key
                ;;
            7)
                read -p "  Введите имя секрета: " label
                echo ""
                show_qr "$label"
                echo ""
                press_any_key
                ;;
            0)
                return 0
                ;;
        esac
    done
}

show_settings_menu() {
    while true; do
        clear
        echo -e "${BRIGHT_CYAN}${BOLD}"
        echo "╔═══════════════════════════════════════════════════════╗"
        echo "║                    Настройки                          ║"
        echo "╚═══════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        echo -e "  Порт:           ${YELLOW}${PROXY_PORT}${NC}"
        echo -e "  Домен:          ${YELLOW}${PROXY_DOMAIN}${NC}"
        echo -e "  Маскировка:     ${YELLOW}${MASKING_ENABLED}${NC}"
        echo -e "  Ad-Tag:         ${YELLOW}${AD_TAG:-не установлен}${NC}"
        echo ""
        
        echo -e "  [1] Изменить порт"
        echo -e "  [2] Изменить домен"
        echo -e "  [3] Установить Ad-Tag"
        echo -e "  [4] Сохранить настройки"
        echo -e "  [0] Назад"
        echo ""
        
        local choice
        read -p "  Выбор: " choice
        
        case "$choice" in
            1)
                read -p "  Новый порт: " PROXY_PORT
                ;;
            2)
                read -p "  Новый домен: " PROXY_DOMAIN
                ;;
            3)
                read -p "  Ad-Tag: " AD_TAG
                ;;
            4)
                save_settings
                log_success "Настройки сохранены"
                press_any_key
                ;;
            0)
                return 0
                ;;
        esac
    done
}

press_any_key() {
    echo -en "\n  ${DIM}Нажмите любую клавишу...${NC}"
    read -rsn1
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# Основной цикл TUI
# ═══════════════════════════════════════════════════════════════
run_tui() {
    while true; do
        show_main_menu
        
        local choice
        read -p "  Выбор: " choice
        
        case "$choice" in
            1)
                engine_status
                press_any_key
                ;;
            2)
                show_secrets_menu
                ;;
            3)
                start_engine
                press_any_key
                ;;
            4)
                stop_engine
                press_any_key
                ;;
            5)
                restart_engine
                press_any_key
                ;;
            6)
                show_settings_menu
                ;;
            7)
                if [ -f /var/log/mtproxymax.log ]; then
                    tail -50 /var/log/mtproxymax.log
                else
                    log_info "Лог файл пуст"
                fi
                press_any_key
                ;;
            8)
                log_info "Обновление движка..."
                bash "$ENGINE_DIR/install_engine.sh"
                press_any_key
                ;;
            0)
                echo -e "\n  ${CYAN}До свидания!${NC}"
                exit 0
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════
# CLI команды
# ═══════════════════════════════════════════════════════════════
show_help() {
    echo -e "${CYAN}MTProxyMax Native — The Ultimate Telegram Proxy Manager${NC}"
    echo -e "${DIM}Версия: ${VERSION}${NC}"
    echo ""
    echo "Использование: $0 <команда> [аргументы]"
    echo ""
    echo "Команды:"
    echo "  menu                  Открыть интерактивное меню (TUI)"
    echo "  status                Показать статус прокси"
    echo "  start                 Запустить прокси"
    echo "  stop                  Остановить прокси"
    echo "  restart               Перезапустить прокси"
    echo ""
    echo "  secret add <label>    Добавить секрет"
    echo "  secret remove <label> Удалить секрет"
    echo "  secret list           Список секретов"
    echo "  secret enable <label> Включить секрет"
    echo "  secret disable <label> Отключить секрет"
    echo "  secret rotate <label> Обновить ключ секрета"
    echo "  secret link <label>   Показать ссылку"
    echo "  secret qr <label>     Показать QR-код"
    echo "  secret setlimit <label> <type> <value> — установить лимит"
    echo ""
    echo "  settings              Настройки (порт, домен, ad-tag)"
    echo "  engine status         Статус движка"
    echo "  engine rebuild        Пересобрать движок"
    echo "  logs                  Показать логи"
    echo "  update                Обновить скрипт"
    echo "  help                  Эта справка"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════
main() {
    load_settings
    load_secrets
    
    case "${1:-menu}" in
        menu)
            run_tui
            ;;
        status)
            engine_status
            ;;
        start)
            start_engine
            ;;
        stop)
            stop_engine
            ;;
        restart)
            restart_engine
            ;;
        secret)
            case "${2:-}" in
                add) secret_add "$3" ;;
                remove) secret_remove "$3" ;;
                list) secret_list ;;
                enable) secret_enable "$3" ;;
                disable) secret_disable "$3" ;;
                rotate) secret_rotate "$3" ;;
                link) get_proxy_link "$3" ;;
                qr) show_qr "$3" ;;
                setlimit) secret_setlimit "$3" "$4" "$5" ;;
                *) log_error "Неизвестная команда: secret $2"; exit 1 ;;
            esac
            ;;
        settings)
            show_settings_menu
            ;;
        engine)
            case "${2:-}" in
                status) engine_status ;;
                rebuild) 
                    log_info "Пересборка..."
                    bash "$ENGINE_DIR/install_engine.sh"
                    ;;
                *) log_error "Неизвестная команда: engine $2"; exit 1 ;;
            esac
            ;;
        logs)
            if [ -f /var/log/mtproxymax.log ]; then
                tail -100 /var/log/mtproxymax.log
            else
                log_info "Лог файл пуст"
            fi
            ;;
        update)
            log_info "Проверка обновлений..."
            # TODO: реализация обновления
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Неизвестная команда: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
