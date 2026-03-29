#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  Система локализации для MTProxyMax
# ═══════════════════════════════════════════════════════════════

# Директория с локалями
LOCALES_DIR="${LOCALES_DIR:-/opt/mtproxymax/locales}"

# Текущий язык (по умолчанию русский)
CURRENT_LANG="${CURRENT_LANG:-ru}"

# Ассоциативный массив для переводов
declare -A LANG_STRINGS

# Загрузка переводов из JSON файла
load_locale() {
    local lang="${1:-$CURRENT_LANG}"
    local locale_file="$LOCALES_DIR/${lang}.json"
    
    # Если файл не найден, пробуем английский как fallback
    if [ ! -f "$locale_file" ]; then
        locale_file="$LOCALES_DIR/en.json"
        [ ! -f "$locale_file" ] && return 1
        lang="en"
    fi
    
    CURRENT_LANG="$lang"
    LANG_STRINGS=()
    
    # Парсим JSON (простой парсер для плоской структуры)
    while IFS= read -r line; do
        # Пропускаем скобки и пустые строки
        [[ "$line" =~ ^[[:space:]]*[\{\}] ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        
        # Извлекаем ключ и значение из "key": "value"
        if [[ "$line" =~ ^[[:space:]]*\"([^\"]+)\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            LANG_STRINGS["$key"]="$value"
        fi
    done < "$locale_file"
    
    return 0
}

# Получение строки по ключу
t() {
    local key="$1"
    shift
    local args=("$@")
    
    local string="${LANG_STRINGS[$key]:-$key}"
    
    # Замена плейсхолдеров {label}, {value}, etc.
    for i in "${!args[@]}"; do
        string="${string//\{label\}/${args[$i]}}"
        string="${string//\{value\}/${args[$i]}}"
    done
    
    echo "$string"
}

# Псевдонимы для часто используемых строк
_() {
    t "$@"
}

# Инициализация локализации
init_locale() {
    local lang="${1:-ru}"
    
    # Определяем директорию с локалями
    if [ -d "./locales" ]; then
        LOCALES_DIR="./locales"
    elif [ -d "/opt/mtproxymax/locales" ]; then
        LOCALES_DIR="/opt/mtproxymax/locales"
    elif [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/locales" ]; then
        LOCALES_DIR="$SCRIPT_DIR/locales"
    fi
    
    # Загружаем переводы
    load_locale "$lang" || {
        # Fallback на английский
        load_locale "en"
    }
}

# Установка языка
set_lang() {
    local lang="$1"
    load_locale "$lang"
}

# Получение текущего языка
get_lang() {
    echo "$CURRENT_LANG"
}

# Список доступных языков
list_langs() {
    local langs=()
    for f in "$LOCALES_DIR"/*.json; do
        [ -f "$f" ] || continue
        local lang
        lang=$(basename "$f" .json)
        langs+=("$lang")
    done
    echo "${langs[@]}"
}

# Автосопоставление языка системы
detect_lang() {
    local sys_lang="${LANG:-${LC_ALL:-en_US.UTF-8}}"
    
    case "$sys_lang" in
        ru*|RU*|russian*) echo "ru" ;;
        en*|EN*|english*) echo "en" ;;
        uk*|UK*|ukrainian*) echo "ru" ;;
        be*|BE*|belarusian*) echo "ru" ;;
        kk*|KK*|kazakh*) echo "ru" ;;
        *) echo "en" ;;
    esac
}

# Инициализация при загрузке
if [ -z "$MTPOXYMAX_LOCALE_INIT" ]; then
    MTPOXYMAX_LOCALE_INIT=1
    init_locale "$(detect_lang)"
fi
