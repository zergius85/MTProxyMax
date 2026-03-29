#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════
#  MTProxyMax Telegram Bot с inline-меню
#  Copyright (c) 2026 SamNet Technologies
# ═══════════════════════════════════════════════════════════════
"""
Telegram бот для управления MTProxyMax
С inline-кнопками и вложенными меню
"""

import os
import sys
import asyncio
import subprocess
import json
from pathlib import Path
from datetime import datetime
from typing import Optional, List

from aiogram import Bot, Dispatcher, F, types
from aiogram.filters import Command, CommandStart
from aiogram.types import (
    InlineKeyboardMarkup,
    InlineKeyboardButton,
    KeyboardButton,
    ReplyKeyboardMarkup,
    WebAppInfo,
)
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from dotenv import load_dotenv

# ═══════════════════════════════════════════════════════════════
# Конфигурация
# ═══════════════════════════════════════════════════════════════
load_dotenv()

BOT_TOKEN = os.getenv("MTPOXYMAX_BOT_TOKEN", "")
ADMIN_IDS = os.getenv("MTPOXYMAX_ADMIN_IDS", "").split(",")
ADMIN_IDS = [int(x.strip()) for x in ADMIN_IDS if x.strip().isdigit()]

INSTALL_DIR = Path("/opt/mtproxymax")
SETTINGS_FILE = INSTALL_DIR / "settings.conf"
SECRETS_FILE = INSTALL_DIR / "secrets.conf"

SCRIPT = INSTALL_DIR / "mtproxymax-native.sh"

# ═══════════════════════════════════════════════════════════════
# Инициализация бота
# ═══════════════════════════════════════════════════════════════
bot = Bot(token=BOT_TOKEN)
dp = Dispatcher()

# ═══════════════════════════════════════════════════════════════
# Клавиатуры
# ═══════════════════════════════════════════════════════════════
def get_main_keyboard() -> InlineKeyboardMarkup:
    """Главное меню с inline-кнопками"""
    keyboard = [
        [
            InlineKeyboardButton(text="📊 Статус", callback_data="main_status"),
            InlineKeyboardButton(text="👥 Секреты", callback_data="main_secrets"),
        ],
        [
            InlineKeyboardButton(text="🔗 Моя ссылка", callback_data="main_link"),
            InlineKeyboardButton(text="📈 Трафик", callback_data="main_traffic"),
        ],
        [
            InlineKeyboardButton(text="⚙️ Настройки", callback_data="main_settings"),
            InlineKeyboardButton(text="🔧 Управление", callback_data="main_control"),
        ],
        [
            InlineKeyboardButton(text="📖 Помощь", callback_data="main_help"),
        ],
    ]
    return InlineKeyboardMarkup(keyboard=keyboard)

def get_secrets_keyboard() -> InlineKeyboardMarkup:
    """Меню управления секретами"""
    keyboard = [
        [
            InlineKeyboardButton(text="➕ Добавить", callback_data="secret_add"),
            InlineKeyboardButton(text="📋 Список", callback_data="secret_list"),
        ],
        [
            InlineKeyboardButton(text="🔄 Обновить", callback_data="secret_rotate_menu"),
            InlineKeyboardButton(text="🗑️ Удалить", callback_data="secret_remove_menu"),
        ],
        [
            InlineKeyboardButton(text="🔙 Назад", callback_data="main_menu"),
        ],
    ]
    return InlineKeyboardMarkup(keyboard=keyboard)

def get_secret_item_keyboard(label: str) -> InlineKeyboardMarkup:
    """Клавиатура для конкретного секрета"""
    keyboard = [
        [
            InlineKeyboardButton(text="🔗 Ссылка", callback_data=f"secret_link_{label}"),
            InlineKeyboardButton(text="📱 QR", callback_data=f"secret_qr_{label}"),
        ],
        [
            InlineKeyboardButton(text="⏸️ Отключить" if is_secret_enabled(label) else "▶️ Включить", 
                               callback_data=f"secret_toggle_{label}"),
            InlineKeyboardButton(text="🔄 Обновить ключ", callback_data=f"secret_rotate_{label}"),
        ],
        [
            InlineKeyboardButton(text="📊 Лимиты", callback_data=f"secret_limits_{label}"),
            InlineKeyboardButton(text="🗑️ Удалить", callback_data=f"secret_delete_{label}"),
        ],
        [
            InlineKeyboardButton(text="🔙 Назад к списку", callback_data="secret_list"),
        ],
    ]
    return InlineKeyboardMarkup(keyboard=keyboard)

def get_limits_keyboard(label: str) -> InlineKeyboardMarkup:
    """Клавиатура для установки лимитов"""
    keyboard = [
        [
            InlineKeyboardButton(text="📱 Устройства", callback_data=f"limit_conns_{label}"),
            InlineKeyboardButton(text="🌐 IP адреса", callback_data=f"limit_ips_{label}"),
        ],
        [
            InlineKeyboardButton(text="💾 Трафик", callback_data=f"limit_quota_{label}"),
            InlineKeyboardButton(text="📅 Срок", callback_data=f"limit_expires_{label}"),
        ],
        [
            InlineKeyboardButton(text="🔙 Назад", callback_data=f"secret_item_{label}"),
        ],
    ]
    return InlineKeyboardMarkup(keyboard=keyboard)

def get_control_keyboard() -> InlineKeyboardMarkup:
    """Клавиатура управления прокси"""
    keyboard = [
        [
            InlineKeyboardButton(text="🚀 Запустить", callback_data="control_start"),
            InlineKeyboardButton(text="⏹️ Остановить", callback_data="control_stop"),
        ],
        [
            InlineKeyboardButton(text="🔄 Перезапустить", callback_data="control_restart"),
        ],
        [
            InlineKeyboardButton(text="📋 Логи", callback_data="control_logs"),
        ],
        [
            InlineKeyboardButton(text="🔙 Назад", callback_data="main_menu"),
        ],
    ]
    return InlineKeyboardMarkup(keyboard=keyboard)

def get_settings_keyboard() -> InlineKeyboardMarkup:
    """Клавиатура настроек"""
    keyboard = [
        [
            InlineKeyboardButton(text="🔌 Порт", callback_data="settings_port"),
            InlineKeyboardButton(text="🌐 Домен", callback_data="settings_domain"),
        ],
        [
            InlineKeyboardButton(text="📺 Ad-Tag", callback_data="settings_adtag"),
        ],
        [
            InlineKeyboardButton(text="🔙 Назад", callback_data="main_menu"),
        ],
    ]
    return InlineKeyboardMarkup(keyboard=keyboard)

def get_back_keyboard() -> InlineKeyboardMarkup:
    """Простая кнопка назад"""
    keyboard = [
        [InlineKeyboardButton(text="🔙 Назад", callback_data="main_menu")],
    ]
    return InlineKeyboardMarkup(keyboard=keyboard)

# ═══════════════════════════════════════════════════════════════
# Утилиты
# ═══════════════════════════════════════════════════════════════
def check_admin(user_id: int) -> bool:
    """Проверка прав администратора"""
    if not ADMIN_IDS:
        return True  # Если админы не указаны, разрешаем всем
    return user_id in ADMIN_IDS

def run_command(args: List[str], timeout: int = 30) -> dict:
    """Выполнение команды mtproxymax-native.sh"""
    cmd = ["bash", str(SCRIPT)] + args
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
        }
    except subprocess.TimeoutExpired:
        return {"success": False, "error": "Command timeout"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def parse_secrets() -> List[dict]:
    """Парсинг файла секретов"""
    secrets = []
    
    if SECRETS_FILE.exists():
        with open(SECRETS_FILE, "r") as f:
            for line in f:
                line = line.strip()
                if line.startswith("#") or not line:
                    continue
                
                parts = line.split("|")
                if len(parts) >= 2:
                    secrets.append({
                        "label": parts[0],
                        "secret": parts[1],
                        "enabled": parts[3] == "true" if len(parts) > 3 else True,
                        "max_conns": int(parts[4]) if len(parts) > 4 and parts[4].isdigit() else 0,
                        "quota": parts[6] if len(parts) > 6 else "0",
                        "expires": parts[7] if len(parts) > 7 else "0",
                    })
    
    return secrets

def is_secret_enabled(label: str) -> bool:
    """Проверка статуса секрета"""
    secrets = parse_secrets()
    for secret in secrets:
        if secret["label"] == label:
            return secret["enabled"]
    return False

def parse_settings() -> dict:
    """Парсинг настроек"""
    settings = {}
    
    if SETTINGS_FILE.exists():
        with open(SETTINGS_FILE, "r") as f:
            for line in f:
                line = line.strip()
                if line.startswith("#") or not line or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                settings[key.strip()] = value.strip().strip("'\"")
    
    return settings

def get_proxy_link(label: Optional[str] = None) -> str:
    """Получение ссылки на прокси"""
    args = ["secret", "link"]
    if label:
        args.append(label)
    
    result = run_command(args)
    return result.get("stdout", "") if result["success"] else ""

def build_faketls_link(secret: str, domain: str, port: int, ip: str) -> str:
    """Построение FakeTLS ссылки"""
    domain_hex = domain.encode().hex()
    full_secret = f"ee{secret}{domain_hex}"
    return f"tg://proxy?server={ip}&port={port}&secret={full_secret}"

# ═══════════════════════════════════════════════════════════════
# Машина состояний для ввода данных
# ═══════════════════════════════════════════════════════════════
class SecretForm(StatesGroup):
    name = State()
    conns = State()
    quota = State()
    expires = State()

class SettingsForm(StatesGroup):
    port = State()
    domain = State()
    adtag = State()

# Хендлеры для мастера добавления секрета
@dp.callback_query(F.data == "secret_add")
async def cb_secret_add_start(callback: types.CallbackQuery, state: FSMContext):
    """Начало добавления секрета"""
    await callback.message.edit_text(
        "➕ <b>Добавление нового секрета</b>\n\n"
        "Введите имя для нового секрета (латиницей, без пробелов):\n"
        "<i>Например: alice, user1, family</i>",
        reply_markup=InlineKeyboardMarkup(keyboard=[[
            InlineKeyboardButton(text="🔙 Отмена", callback_data="main_secrets")
        ]])
    )
    await state.set_state(SecretForm.name)

@dp.message(SecretForm.name)
async def secret_add_name(message: types.Message, state: FSMContext):
    """Обработка имени секрета"""
    name = message.text.strip()
    
    # Проверка имени
    if not name or len(name) > 32:
        await message.answer("❌ Имя должно быть от 1 до 32 символов. Попробуйте ещё раз:")
        return
    
    if not name.replace("_", "").replace("-", "").isalnum():
        await message.answer("❌ Имя должно содержать только латинские буквы, цифры, _ и -. Попробуйте ещё раз:")
        return
    
    # Проверка на дубликат
    secrets = parse_secrets()
    if any(s["label"] == name for s in secrets):
        await message.answer(f"❌ Секрет с именем '{name}' уже существует. Попробуйте другое имя:")
        return
    
    await state.update_data(name=name)
    
    await message.answer(
        "✅ Имя принято.\n\n"
        "Теперь введите максимальное количество устройств (0 = без лимита):\n"
        "<i>Например: 3 для ограничения до 3 устройств</i>",
        reply_markup=InlineKeyboardMarkup(keyboard=[[
            InlineKeyboardButton(text="⏭️ Пропустить", callback_data="skip_conns")
        ]])
    )
    await state.set_state(SecretForm.conns)

@dp.callback_query(F.data == "skip_conns")
async def skip_conns(callback: types.CallbackQuery, state: FSMContext):
    """Пропуск лимита подключений"""
    await state.update_data(conns=0)
    await callback.message.edit_text(
        "✅ Лимит устройств: ∞\n\n"
        "Теперь введите лимит трафика (0 = без лимита):\n"
        "<i>Например: 10G, 500M, 1T</i>",
        reply_markup=InlineKeyboardMarkup(keyboard=[[
            InlineKeyboardButton(text="⏭️ Пропустить", callback_data="skip_quota")
        ]])
    )
    await state.set_state(SecretForm.quota)

@dp.message(SecretForm.conns)
async def secret_add_conns(message: types.Message, state: FSMContext):
    """Обработка лимита подключений"""
    try:
        conns = int(message.text.strip())
        if conns < 0:
            raise ValueError()
    except ValueError:
        await message.answer("❌ Введите число от 0 до 9999. Попробуйте ещё раз:")
        return
    
    await state.update_data(conns=conns)
    
    await message.answer(
        f"✅ Лимит устройств: {conns if conns > 0 else '∞'}\n\n"
        "Теперь введите лимит трафика (0 = без лимита):\n"
        "<i>Например: 10G, 500M, 1T</i>",
        reply_markup=InlineKeyboardMarkup(keyboard=[[
            InlineKeyboardButton(text="⏭️ Пропустить", callback_data="skip_quota")
        ]])
    )
    await state.set_state(SecretForm.quota)

@dp.callback_query(F.data == "skip_quota")
async def skip_quota(callback: types.CallbackQuery, state: FSMContext):
    """Пропуск лимита трафика"""
    await state.update_data(quota="0")
    await callback.message.edit_text(
        "✅ Лимит трафика: ∞\n\n"
        "Введите дату истечения в формате ГГГГ-ММ-ДД (или 0 = без лимита):\n"
        "<i>Например: 2026-12-31</i>",
        reply_markup=InlineKeyboardMarkup(keyboard=[[
            InlineKeyboardButton(text="⏭️ Пропустить", callback_data="skip_expires")
        ]])
    )
    await state.set_state(SecretForm.expires)

@dp.message(SecretForm.quota)
async def secret_add_quota(message: types.Message, state: FSMContext):
    """Обработка лимита трафика"""
    quota = message.text.strip().upper()
    
    if quota == "0":
        quota = "0"
    elif not (quota.endswith("G") or quota.endswith("M") or quota.endswith("T") or quota.endswith("K")):
        await message.answer("❌ Формат: число + G/M/T/K (например, 10G). Попробуйте ещё раз:")
        return
    
    await state.update_data(quota=quota)
    
    await message.answer(
        f"✅ Лимит трафика: {quota if quota != '0' else '∞'}\n\n"
        "Введите дату истечения в формате ГГГГ-ММ-ДД (или 0 = без лимита):\n"
        "<i>Например: 2026-12-31</i>",
        reply_markup=InlineKeyboardMarkup(keyboard=[[
            InlineKeyboardButton(text="⏭️ Пропустить", callback_data="skip_expires")
        ]])
    )
    await state.set_state(SecretForm.expires)

@dp.callback_query(F.data == "skip_expires")
async def skip_expires(callback: types.CallbackQuery, state: FSMContext):
    """Пропуск срока действия"""
    await state.update_data(expires="0")
    await create_secret_final(callback.message, state)

@dp.message(SecretForm.expires)
async def secret_add_expires(message: types.Message, state: FSMContext):
    """Обработка срока действия"""
    expires = message.text.strip()
    
    if expires == "0":
        expires = "0"
    else:
        try:
            datetime.strptime(expires, "%Y-%m-%d")
        except ValueError:
            await message.answer("❌ Формат: ГГГГ-ММ-ДД (например, 2026-12-31). Попробуйте ещё раз:")
            return
    
    await state.update_data(expires=expires)
    await create_secret_final(message, state)

async def create_secret_final(message: types.Message, state: FSMContext):
    """Финальное создание секрета"""
    data = await state.get_data()
    name = data["name"]
    conns = data["conns"]
    quota = data["quota"]
    expires = data["expires"]
    
    # Создаём секрет
    result = run_command(["secret", "add", name])
    
    if not result["success"]:
        await message.answer(
            f"❌ Ошибка создания секрета:\n{result.get('stderr', 'Неизвестная ошибка')}",
            reply_markup=get_secrets_keyboard()
        )
        await state.clear()
        return
    
    # Устанавливаем лимиты
    if conns > 0:
        run_command(["secret", "setlimit", name, "conns", str(conns)])
    if quota != "0":
        run_command(["secret", "setlimit", name, "quota", quota])
    if expires != "0":
        run_command(["secret", "setlimit", name, "expires", expires])
    
    # Получаем ссылку
    link_result = run_command(["secret", "link", name])
    link = link_result.get("stdout", "")
    
    await message.answer(
        f"✅ <b>Секрет '{name}' создан!</b>\n\n"
        f"🔹 Устройства: {conns if conns > 0 else '∞'}\n"
        f"🔹 Трафик: {quota if quota != '0' else '∞'}\n"
        f"🔹 Истекает: {expires if expires != '0' else '∞'}\n\n"
        f"🔗 <b>Ссылка:</b>\n"
        f"<code>{link}</code>\n\n"
        f"Отправьте ссылку пользователю или покажите QR-код.",
        reply_markup=get_secrets_keyboard()
    )
    
    await state.clear()

# ═══════════════════════════════════════════════════════════════
# Хендлеры
# ═══════════════════════════════════════════════════════════════
@dp.message(CommandStart())
async def cmd_start(message: types.Message):
    """Команда /start"""
    if not check_admin(message.from_user.id):
        await message.answer("❌ У вас нет доступа к управлению прокси.")
        return
    
    await message.answer(
        f"👋 <b>Привет, {message.from_user.first_name}!</b>\n\n"
        "Я бот для управления <b>MTProxyMax</b>.\n"
        "Выберите действие в меню ниже:",
        reply_markup=get_main_keyboard(),
    )

@dp.message(Command("menu"))
async def cmd_menu(message: types.Message):
    """Команда /menu — показать главное меню"""
    if not check_admin(message.from_user.id):
        return
    
    await message.answer(
        "📋 <b>Главное меню</b>",
        reply_markup=get_main_keyboard(),
    )

@dp.message(Command("help"))
async def cmd_help(message: types.Message):
    """Команда /help"""
    help_text = """
📖 <b>Помощь по MTProxyMax Bot</b>

<b>Основные команды:</b>
/start — Запустить бота
/menu — Показать главное меню
/status — Статус прокси
/link — Ссылка на подключение

<b>Управление секретами:</b>
/add — Добавить секрет
/list — Список секретов
/rotate — Обновить ключ

<b>Настройки:</b>
/settings — Настройки прокси

Нажмите на кнопки в меню для управления.
    """
    await message.answer(help_text)

# ═══════════════════════════════════════════════════════════════
# Callback query handlers — Главное меню
# ═══════════════════════════════════════════════════════════════
@dp.callback_query(F.data == "main_menu")
async def cb_main_menu(callback: types.CallbackQuery):
    """Возврат в главное меню"""
    await callback.message.edit_text(
        "📋 <b>Главное меню</b>\nВыберите действие:",
        reply_markup=get_main_keyboard(),
    )

@dp.callback_query(F.data == "main_status")
async def cb_main_status(callback: types.CallbackQuery):
    """Статус прокси"""
    settings = parse_settings()
    secrets = parse_secrets()
    
    # Проверка запуска
    pid_file = Path("/run/mtproxymax.pid")
    is_running = pid_file.exists()
    
    status_text = f"""
📊 <b>Статус MTProxyMax</b>

🔹 Статус: {'🟢 Запущен' if is_running else '🔴 Остановлен'}
🔹 Порт: {settings.get('PROXY_PORT', '443')}
🔹 Домен: {settings.get('PROXY_DOMAIN', 'cloudflare.com')}
🔹 Секретов: {len(secrets)}
🔹 Активных: {sum(1 for s in secrets if s['enabled'])}
    """
    
    await callback.message.edit_text(
        status_text,
        reply_markup=get_back_keyboard(),
    )

@dp.callback_query(F.data == "main_secrets")
async def cb_main_secrets(callback: types.CallbackQuery):
    """Меню секретов"""
    await callback.message.edit_text(
        "👥 <b>Управление секретами</b>\nВыберите действие:",
        reply_markup=get_secrets_keyboard(),
    )

@dp.callback_query(F.data == "main_link")
async def cb_main_link(callback: types.CallbackQuery):
    """Ссылка на прокси"""
    settings = parse_settings()
    secrets = parse_secrets()
    
    if not secrets:
        await callback.message.edit_text(
            "❌ Нет активных секретов",
            reply_markup=get_back_keyboard(),
        )
        return
    
    # Берём первый активный секрет
    active_secret = next((s for s in secrets if s['enabled']), None)
    if not active_secret:
        await callback.message.edit_text(
            "❌ Нет активных секретов",
            reply_markup=get_back_keyboard(),
        )
        return
    
    ip = settings.get('CUSTOM_IP', 'YOUR_SERVER_IP')
    link = build_faketls_link(
        active_secret['secret'],
        settings.get('PROXY_DOMAIN', 'cloudflare.com'),
        int(settings.get('PROXY_PORT', 443)),
        ip
    )
    
    await callback.message.edit_text(
        f"🔗 <b>Ваша ссылка на подключение:</b>\n\n"
        f"<code>{link}</code>\n\n"
        f"Нажмите для подключения или отсканируйте QR.",
        reply_markup=get_back_keyboard(),
    )

@dp.callback_query(F.data == "main_traffic")
async def cb_main_traffic(callback: types.CallbackQuery):
    """Трафик"""
    # TODO: Реализовать получение трафика
    await callback.message.edit_text(
        "📈 <b>Статистика трафика</b>\n\n"
        "Функция в разработке...",
        reply_markup=get_back_keyboard(),
    )

@dp.callback_query(F.data == "main_settings")
async def cb_main_settings(callback: types.CallbackQuery):
    """Настройки"""
    await callback.message.edit_text(
        "⚙️ <b>Настройки прокси</b>",
        reply_markup=get_settings_keyboard(),
    )

@dp.callback_query(F.data == "main_control")
async def cb_main_control(callback: types.CallbackQuery):
    """Управление прокси"""
    await callback.message.edit_text(
        "🔧 <b>Управление прокси</b>",
        reply_markup=get_control_keyboard(),
    )

@dp.callback_query(F.data == "main_help")
async def cb_main_help(callback: types.CallbackQuery):
    """Помощь"""
    help_text = """
📖 <b>Помощь</b>

Этот бот позволяет управлять MTProxyMax прямо из Telegram.

<b>Возможности:</b>
• Просмотр статуса прокси
• Управление секретами (добавление, удаление, лимиты)
• Настройка порта, домена, Ad-Tag
• Запуск/остановка прокси
• Получение ссылок и QR-кодов

<b>Советы:</b>
• Используйте лимиты для ограничения пользователей
• Регулярно обновляйте секреты
• Следите за трафиком в логах
    """
    await callback.message.edit_text(
        help_text,
        reply_markup=get_back_keyboard(),
    )

# ═══════════════════════════════════════════════════════════════
# Callback query handlers — Секреты
# ═══════════════════════════════════════════════════════════════
@dp.callback_query(F.data == "secret_list")
async def cb_secret_list(callback: types.CallbackQuery):
    """Список секретов"""
    secrets = parse_secrets()
    
    if not secrets:
        await callback.message.edit_text(
            "📋 <b>Список секретов</b>\n\nПусто",
            reply_markup=get_secrets_keyboard(),
        )
        return
    
    text = "📋 <b>Список секретов</b>\n\n"
    for secret in secrets:
        status = "🟢" if secret['enabled'] else "🔴"
        conns = secret['max_conns'] if secret['max_conns'] > 0 else "∞"
        text += f"{status} <b>{secret['label']}</b> (устр: {conns})\n"
    
    # Добавляем кнопки для каждого секрета
    keyboard = []
    for secret in secrets:
        keyboard.append([
            InlineKeyboardButton(
                text=f"{'🟢' if secret['enabled'] else '🔴'} {secret['label']}",
                callback_data=f"secret_item_{secret['label']}"
            )
        ])
    keyboard.append([InlineKeyboardButton(text="🔙 Назад", callback_data="main_secrets")])
    
    await callback.message.edit_text(
        text,
        reply_markup=InlineKeyboardMarkup(keyboard=keyboard),
    )

@dp.callback_query(F.data.startswith("secret_item_"))
async def cb_secret_item(callback: types.CallbackQuery):
    """Детали секрета"""
    label = callback.data.replace("secret_item_", "")
    secrets = parse_secrets()
    
    secret = next((s for s in secrets if s['label'] == label), None)
    if not secret:
        await callback.answer("❌ Секрет не найден", show_alert=True)
        return
    
    text = f"""
🔑 <b>Секрет: {label}</b>

Статус: {'🟢 Активен' if secret['enabled'] else '🔴 Отключен'}
Устройства: {secret['max_conns'] if secret['max_conns'] > 0 else '∞'}
Трафик: {secret['quota'] if secret['quota'] != '0' else '∞'}
Истекает: {secret['expires'] if secret['expires'] != '0' else '∞'}
    """
    
    await callback.message.edit_text(
        text,
        reply_markup=get_secret_item_keyboard(label),
    )

@dp.callback_query(F.data.startswith("secret_link_"))
async def cb_secret_link(callback: types.CallbackQuery):
    """Ссылка секрета"""
    label = callback.data.replace("secret_link_", "")
    settings = parse_settings()
    secrets = parse_secrets()
    
    secret = next((s for s in secrets if s['label'] == label), None)
    if not secret:
        await callback.answer("❌ Секрет не найден", show_alert=True)
        return
    
    ip = settings.get('CUSTOM_IP', 'YOUR_SERVER_IP')
    link = build_faketls_link(
        secret['secret'],
        settings.get('PROXY_DOMAIN', 'cloudflare.com'),
        int(settings.get('PROXY_PORT', 443)),
        ip
    )
    
    await callback.message.edit_text(
        f"🔗 <b>Ссылка для {label}:</b>\n\n"
        f"<code>{link}</code>",
        reply_markup=get_back_keyboard(),
    )

@dp.callback_query(F.data.startswith("secret_toggle_"))
async def cb_secret_toggle(callback: types.CallbackQuery):
    """Включить/отключить секрет"""
    label = callback.data.replace("secret_toggle_", "")
    
    current_state = is_secret_enabled(label)
    command = "disable" if current_state else "enable"
    
    result = run_command(["secret", command, label])
    
    if result["success"]:
        await callback.answer(f"✅ Секрет {'включён' if not current_state else 'отключён'}")
        await cb_secret_item(callback)
    else:
        await callback.answer("❌ Ошибка: " + result.get("stderr", "Неизвестная ошибка"), show_alert=True)

@dp.callback_query(F.data.startswith("secret_rotate_"))
async def cb_secret_rotate(callback: types.CallbackQuery):
    """Обновить ключ секрета"""
    label = callback.data.replace("secret_rotate_", "")
    
    result = run_command(["secret", "rotate", label])
    
    if result["success"]:
        await callback.answer("✅ Ключ обновлён")
        await cb_secret_item(callback)
    else:
        await callback.answer("❌ Ошибка: " + result.get("stderr", "Неизвестная ошибка"), show_alert=True)

@dp.callback_query(F.data.startswith("secret_delete_"))
async def cb_secret_delete(callback: types.CallbackQuery):
    """Удалить секрет"""
    label = callback.data.replace("secret_delete_", "")
    
    result = run_command(["secret", "remove", label])
    
    if result["success"]:
        await callback.answer("✅ Секрет удалён")
        await cb_secret_list(callback)
    else:
        await callback.answer("❌ Ошибка: " + result.get("stderr", "Неизвестная ошибка"), show_alert=True)

@dp.callback_query(F.data.startswith("secret_limits_"))
async def cb_secret_limits(callback: types.CallbackQuery):
    """Лимиты секрета"""
    label = callback.data.replace("secret_limits_", "")
    await callback.message.edit_text(
        f"📊 <b>Лимиты для {label}</b>",
        reply_markup=get_limits_keyboard(label),
    )

# ═══════════════════════════════════════════════════════════════
# Callback query handlers — Управление
# ═══════════════════════════════════════════════════════════════
@dp.callback_query(F.data == "control_start")
async def cb_control_start(callback: types.CallbackQuery):
    """Запуск прокси"""
    await callback.answer("⏳ Запуск...")
    result = run_command(["start"])
    
    if result["success"]:
        await callback.message.edit_text(
            "🚀 <b>Прокси запущен!</b>",
            reply_markup=get_control_keyboard(),
        )
    else:
        await callback.message.edit_text(
            f"❌ <b>Ошибка запуска:</b>\n{result.get('stderr', 'Неизвестная ошибка')}",
            reply_markup=get_control_keyboard(),
        )

@dp.callback_query(F.data == "control_stop")
async def cb_control_stop(callback: types.CallbackQuery):
    """Остановка прокси"""
    await callback.answer("⏳ Остановка...")
    result = run_command(["stop"])
    
    if result["success"]:
        await callback.message.edit_text(
            "⏹️ <b>Прокси остановлен</b>",
            reply_markup=get_control_keyboard(),
        )
    else:
        await callback.message.edit_text(
            f"❌ <b>Ошибка остановки:</b>\n{result.get('stderr', 'Неизвестная ошибка')}",
            reply_markup=get_control_keyboard(),
        )

@dp.callback_query(F.data == "control_restart")
async def cb_control_restart(callback: types.CallbackQuery):
    """Перезапуск прокси"""
    await callback.answer("⏳ Перезапуск...")
    result = run_command(["restart"])
    
    if result["success"]:
        await callback.message.edit_text(
            "🔄 <b>Прокси перезапущен</b>",
            reply_markup=get_control_keyboard(),
        )
    else:
        await callback.message.edit_text(
            f"❌ <b>Ошибка перезапуска:</b>\n{result.get('stderr', 'Неизвестная ошибка')}",
            reply_markup=get_control_keyboard(),
        )

@dp.callback_query(F.data == "control_logs")
async def cb_control_logs(callback: types.CallbackQuery):
    """Логи прокси"""
    log_file = INSTALL_DIR / "mtproxy.log"
    
    if not log_file.exists():
        await callback.message.edit_text(
            "📋 <b>Логи пусты</b>",
            reply_markup=get_control_keyboard(),
        )
        return
    
    with open(log_file, "r") as f:
        lines = f.readlines()[-20:]  # Последние 20 строк
    
    log_text = "".join(lines)
    
    await callback.message.edit_text(
        f"📋 <b>Последние логи:</b>\n\n"
        f"<code>{log_text}</code>",
        reply_markup=get_control_keyboard(),
    )

# ═══════════════════════════════════════════════════════════════
# Запуск бота
# ═══════════════════════════════════════════════════════════════
async def main():
    """Запуск бота"""
    if not BOT_TOKEN:
        print("❌ BOT_TOKEN не указан в переменных окружения!")
        print("Создайте файл .env с переменной MTPOXYMAX_BOT_TOKEN=your_token")
        return
    
    print("🤖 MTProxyMax Bot запускается...")
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())
