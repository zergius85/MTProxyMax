#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  Установка движка telemt без Docker
#  Copyright (c) 2026 SamNet Technologies
# ═══════════════════════════════════════════════════════════════
set -eo pipefail

ENGINE_DIR="/opt/mtproxymax/engine"
TELEMT_VERSION="3.3.32"
TELEMT_COMMIT="a383efc"
GITHUB_REPO="telemt/telemt"

# Цвета
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
    
    log_info "Установка зависимостей..."
    
    case "$os" in
        debian)
            apt-get update -qq
            apt-get install -y -qq curl git build-essential pkg-config libssl-dev systemd
            ;;
        rhel)
            yum install -y -q curl git gcc openssl-devel systemd
            ;;
        alpine)
            apk add --no-cache curl git build-base openssl-dev systemd
            ;;
        *)
            log_warn "Неизвестная ОС, попробуйте установить зависимости вручную"
            return 1
            ;;
    esac
    
    log_success "Зависимости установлены"
}

check_rust() {
    if command -v rustc &>/dev/null && command -v cargo &>/dev/null; then
        local version
        version=$(rustc --version | awk '{print $2}')
        log_info "Rust уже установлен: $version"
        return 0
    fi
    return 1
}

install_rust() {
    log_info "Установка Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env" 2>/dev/null || true
    export PATH="$HOME/.cargo/bin:$PATH"
    log_success "Rust установлен"
}

download_binary() {
    local arch
    arch=$(uname -m)
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$arch" in
        x86_64) arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) 
            log_error "Неподдерживаемая архитектура: $arch"
            return 1
            ;;
    esac
    
    local binary_url="https://github.com/${GITHUB_REPO}/releases/download/v${TELEMT_VERSION}/telemt-${TELEMT_VERSION}-${arch}-unknown-linux-${os}.tar.gz"
    
    log_info "Скачивание telemt v${TELEMT_VERSION} для ${arch}..."
    
    mkdir -p "$ENGINE_DIR"
    cd "$ENGINE_DIR"
    
    if curl -fsSL "$binary_url" -o "telemt.tar.gz" 2>/dev/null; then
        tar -xzf "telemt.tar.gz"
        mv telemt "$ENGINE_DIR/telemt"
        rm -f "telemt.tar.gz"
        chmod +x "$ENGINE_DIR/telemt"
        log_success "Бинарник загружен"
        return 0
    else
        log_warn "Не удалось скачать бинарник, пробуем сборку из исходников..."
        return 1
    fi
}

build_from_source() {
    log_info "Сборка telemt из исходников..."
    
    local src_dir="$ENGINE_DIR/src"
    
    if [ -d "$src_dir" ]; then
        log_info "Исходники уже существуют, обновляем..."
        cd "$src_dir"
        git pull
    else
        log_info "Клонирование репозитория..."
        git clone "https://github.com/${GITHUB_REPO}.git" "$src_dir"
        cd "$src_dir"
    fi
    
    git checkout "$TELEMT_COMMIT" 2>/dev/null || log_warn "Не удалось переключиться на коммит $TELEMT_COMMIT"
    
    log_info "Компиляция (это может занять несколько минут)..."
    cargo build --release
    
    if [ -f "target/release/telemt" ]; then
        cp "target/release/telemt" "$ENGINE_DIR/telemt"
        chmod +x "$ENGINE_DIR/telemt"
        log_success "Сборка завершена"
    else
        log_error "Не удалось найти скомпилированный бинарник"
        return 1
    fi
}

create_systemd_service() {
    log_info "Создание systemd сервиса..."
    
    cat > /etc/systemd/system/mtproxymax-engine.service << 'EOF'
[Unit]
Description=MTProxyMax Engine (telemt)
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/mtproxymax/engine/telemt /opt/mtproxymax/mtproxy/config.toml
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
Environment=RUST_LOG=normal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    log_success "Systemd сервис создан"
}

save_version() {
    echo "${TELEMT_VERSION}-${TELEMT_COMMIT}" > "$ENGINE_DIR/.version"
}

main() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║  Установка MTProxyMax Engine (telemt)      ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_root
    
    install_dependencies
    
    if ! check_rust; then
        install_rust
    fi
    
    if ! download_binary; then
        build_from_source
    fi
    
    create_systemd_service
    save_version
    
    echo ""
    log_success "Установка завершена!"
    echo ""
    echo -e "  Движок: ${CYAN}/opt/mtproxymax/engine/telemt${NC}"
    echo -e "  Сервис: ${CYAN}systemctl start mtproxymax-engine${NC}"
    echo -e "  Логи:   ${CYAN}journalctl -u mtproxymax-engine -f${NC}"
    echo ""
}

main "$@"
