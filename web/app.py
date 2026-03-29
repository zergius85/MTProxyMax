#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════
#  MTProxyMax Web Interface — FastAPI
#  Copyright (c) 2026 SamNet Technologies
# ═══════════════════════════════════════════════════════════════
"""
Веб-интерфейс для управления MTProxyMax
"""

import os
import sys
import json
import subprocess
import shutil
from pathlib import Path
from datetime import datetime
from typing import Optional, List

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel

# ═══════════════════════════════════════════════════════════════
# Конфигурация
# ═══════════════════════════════════════════════════════════════
INSTALL_DIR = Path("/opt/mtproxymax")
SETTINGS_FILE = INSTALL_DIR / "settings.conf"
SECRETS_FILE = INSTALL_DIR / "secrets.conf"
CONFIG_DIR = INSTALL_DIR / "mtproxy"
ENGINE_BIN = INSTALL_DIR / "engine" / "telemt"
ENGINE_PID_FILE = Path("/run/mtproxymax.pid")

SCRIPT_DIR = Path(__file__).parent
TEMPLATES_DIR = SCRIPT_DIR / "templates"
STATIC_DIR = SCRIPT_DIR / "static"

# ═══════════════════════════════════════════════════════════════
# FastAPI приложение
# ═══════════════════════════════════════════════════════════════
app = FastAPI(
    title="MTProxyMax Web",
    description="Веб-интерфейс для управления MTProxyMax",
    version="1.0.0"
)

# Монтирование статики и шаблонов
if STATIC_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

templates = Jinja2Templates(directory=str(TEMPLATES_DIR))

# ═══════════════════════════════════════════════════════════════
# Pydantic модели
# ═══════════════════════════════════════════════════════════════
class SecretCreate(BaseModel):
    label: str
    max_conns: Optional[int] = 0
    max_ips: Optional[int] = 0
    quota: Optional[str] = "0"
    expires: Optional[str] = "0"

class SecretLimit(BaseModel):
    max_conns: Optional[int] = 0
    max_ips: Optional[int] = 0
    quota: Optional[str] = "0"
    expires: Optional[str] = "0"

class SettingsUpdate(BaseModel):
    port: Optional[int] = None
    domain: Optional[str] = None
    ad_tag: Optional[str] = None
    masking_enabled: Optional[bool] = None

# ═══════════════════════════════════════════════════════════════
# Утилиты
# ═══════════════════════════════════════════════════════════════
def run_command(args: List[str], capture_output: bool = True) -> dict:
    """Выполнение команды mtproxymax-native.sh"""
    script = INSTALL_DIR / "mtproxymax-native.sh"
    if not script.exists():
        script = Path(__file__).parent.parent / "mtproxymax-native.sh"
    
    cmd = ["bash", str(script)] + args
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=capture_output,
            text=True,
            timeout=30
        )
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode
        }
    except subprocess.TimeoutExpired:
        return {"success": False, "error": "Command timeout"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def parse_settings() -> dict:
    """Парсинг файла настроек"""
    settings = {
        "PROXY_PORT": 443,
        "PROXY_DOMAIN": "cloudflare.com",
        "AD_TAG": "",
        "MASKING_ENABLED": "true",
        "CUSTOM_IP": "",
        "FAKE_CERT_LEN": 2048,
        "PROXY_PROTOCOL": "false",
    }
    
    if SETTINGS_FILE.exists():
        with open(SETTINGS_FILE, "r") as f:
            for line in f:
                line = line.strip()
                if line.startswith("#") or not line:
                    continue
                if "=" in line:
                    key, value = line.split("=", 1)
                    value = value.strip("'\"")
                    settings[key] = value
    
    return settings

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
                    # Извлекаем данные с безопасными значениями по умолчанию
                    label = parts[0]
                    secret = parts[1]
                    created = parts[2] if len(parts) > 2 else ""
                    enabled = parts[3] == "true" if len(parts) > 3 else True
                    
                    # Парсим числовые значения
                    try:
                        max_conns = int(parts[4]) if len(parts) > 4 and parts[4].strip().isdigit() else 0
                    except:
                        max_conns = 0
                    
                    try:
                        max_ips = int(parts[5]) if len(parts) > 5 and parts[5].strip().isdigit() else 0
                    except:
                        max_ips = 0
                    
                    quota = parts[6].strip() if len(parts) > 6 else "0"
                    expires = parts[7].strip() if len(parts) > 7 else "0"
                    notes = parts[8] if len(parts) > 8 else ""
                    
                    secrets.append({
                        "label": label,
                        "secret": secret,
                        "created": created,
                        "enabled": enabled,
                        "max_conns": max_conns,
                        "max_ips": max_ips,
                        "quota": quota,
                        "expires": expires,
                        "notes": notes,
                    })
    
    return secrets

def get_engine_status() -> dict:
    """Получение статуса движка"""
    is_running = False
    pid = None
    
    if ENGINE_PID_FILE.exists():
        try:
            with open(ENGINE_PID_FILE, "r") as f:
                pid = int(f.read().strip())
            # Проверка процесса
            os.kill(pid, 0)
            is_running = True
        except (ValueError, ProcessLookupError, PermissionError):
            pass
    
    if not is_running:
        # Попытка найти через pgrep
        try:
            result = subprocess.run(
                ["pgrep", "-f", "telemt.*config.toml"],
                capture_output=True,
                text=True
            )
            if result.stdout.strip():
                pid = int(result.stdout.strip().split()[0])
                is_running = True
        except:
            pass
    
    version = "unknown"
    if ENGINE_BIN.exists():
        try:
            result = subprocess.run(
                [str(ENGINE_BIN), "--version"],
                capture_output=True,
                text=True
            )
            version = result.stdout.strip().split()[-1] if result.stdout else "unknown"
        except:
            pass
    
    return {
        "running": is_running,
        "pid": pid,
        "version": version,
        "installed": ENGINE_BIN.exists()
    }

def format_bytes(bytes_val: int) -> str:
    """Форматирование байтов в человекочитаемый вид"""
    if bytes_val <= 0:
        return "—"
    
    units = ["B", "KB", "MB", "GB", "TB"]
    unit_index = 0
    value = float(bytes_val)
    
    while value >= 1024 and unit_index < len(units) - 1:
        value /= 1024
        unit_index += 1
    
    if unit_index == 0:
        return f"{int(value)} {units[unit_index]}"
    return f"{value:.2f} {units[unit_index]}"

# ═══════════════════════════════════════════════════════════════
# API Endpoints
# ═══════════════════════════════════════════════════════════════
@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    """Главная страница"""
    with open(TEMPLATES_DIR / "index.html", "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/secrets", response_class=HTMLResponse)
async def secrets_page(request: Request):
    """Страница управления секретами"""
    with open(TEMPLATES_DIR / "secrets.html", "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/settings", response_class=HTMLResponse)
async def settings_page(request: Request):
    """Страница настроек"""
    with open(TEMPLATES_DIR / "settings.html", "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/logs", response_class=HTMLResponse)
async def logs_page(request: Request):
    """Страница логов"""
    with open(TEMPLATES_DIR / "logs.html", "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/status")
async def get_status():
    """Получение общего статуса"""
    engine = get_engine_status()
    settings = parse_settings()
    secrets = parse_secrets()
    
    return {
        "engine": engine,
        "settings": {
            "port": int(settings.get("PROXY_PORT", 443)),
            "domain": settings.get("PROXY_DOMAIN", "cloudflare.com"),
            "ad_tag": settings.get("AD_TAG", ""),
            "masking_enabled": settings.get("MASKING_ENABLED", "true") == "true",
        },
        "secrets_count": len(secrets),
        "active_secrets_count": sum(1 for s in secrets if s["enabled"]),
    }

@app.get("/api/secrets")
async def list_secrets():
    """Список всех секретов"""
    secrets = parse_secrets()
    return {"secrets": secrets}

@app.post("/api/secrets")
async def create_secret(secret: SecretCreate):
    """Создание нового секрета"""
    result = run_command(["secret", "add", secret.label])
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("stderr", "Failed to create secret"))
    
    # Установка лимитов если указаны
    if secret.max_conns > 0:
        run_command(["secret", "setlimit", secret.label, "conns", str(secret.max_conns)])
    if secret.max_ips > 0:
        run_command(["secret", "setlimit", secret.label, "ips", str(secret.max_ips)])
    if secret.quota and secret.quota != "0":
        run_command(["secret", "setlimit", secret.label, "quota", secret.quota])
    if secret.expires and secret.expires != "0":
        run_command(["secret", "setlimit", secret.label, "expires", secret.expires])
    
    return {"success": True, "message": f"Секрет '{secret.label}' создан"}

@app.delete("/api/secrets/{label}")
async def delete_secret(label: str):
    """Удаление секрета"""
    result = run_command(["secret", "remove", label])
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("stderr", "Failed to delete secret"))
    
    return {"success": True, "message": f"Секрет '{label}' удалён"}

@app.post("/api/secrets/{label}/enable")
async def enable_secret(label: str):
    """Включение секрета"""
    result = run_command(["secret", "enable", label])
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("stderr", "Failed to enable secret"))
    
    return {"success": True, "message": f"Секрет '{label}' включён"}

@app.post("/api/secrets/{label}/disable")
async def disable_secret(label: str):
    """Отключение секрета"""
    result = run_command(["secret", "disable", label])
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("stderr", "Failed to disable secret"))
    
    return {"success": True, "message": f"Секрет '{label}' отключён"}

@app.post("/api/secrets/{label}/rotate")
async def rotate_secret(label: str):
    """Обновление ключа секрета"""
    result = run_command(["secret", "rotate", label])
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("stderr", "Failed to rotate secret"))
    
    return {"success": True, "message": f"Секрет '{label}' обновлён"}

@app.put("/api/secrets/{label}/limits")
async def update_secret_limits(label: str, limits: SecretLimit):
    """Обновление лимитов секрета"""
    errors = []
    
    if limits.max_conns is not None:
        result = run_command(["secret", "setlimit", label, "conns", str(limits.max_conns)])
        if not result["success"]:
            errors.append(f"conns: {result.get('stderr', 'failed')}")
    
    if limits.max_ips is not None:
        result = run_command(["secret", "setlimit", label, "ips", str(limits.max_ips)])
        if not result["success"]:
            errors.append(f"ips: {result.get('stderr', 'failed')}")
    
    if limits.quota:
        result = run_command(["secret", "setlimit", label, "quota", limits.quota])
        if not result["success"]:
            errors.append(f"quota: {result.get('stderr', 'failed')}")
    
    if limits.expires:
        result = run_command(["secret", "setlimit", label, "expires", limits.expires])
        if not result["success"]:
            errors.append(f"expires: {result.get('stderr', 'failed')}")
    
    if errors:
        raise HTTPException(status_code=400, detail="; ".join(errors))
    
    return {"success": True, "message": "Лимиты обновлены"}

@app.get("/api/secrets/{label}/link")
async def get_secret_link(label: str):
    """Получение ссылки на подключение"""
    secrets = parse_secrets()
    secret = next((s for s in secrets if s["label"] == label), None)
    
    if not secret:
        raise HTTPException(status_code=404, detail="Secret not found")
    
    settings = parse_settings()
    
    # Получаем публичный IP
    custom_ip = settings.get("CUSTOM_IP", "")
    if not custom_ip:
        try:
            import requests
            custom_ip = requests.get("https://api.ipify.org", timeout=3).text.strip()
        except:
            custom_ip = "YOUR_SERVER_IP"
    
    port = settings.get("PROXY_PORT", "443")
    domain = settings.get("PROXY_DOMAIN", "cloudflare.com")
    
    # Строим FakeTLS ссылку
    domain_hex = domain.encode().hex()
    full_secret = f"ee{secret['secret']}{domain_hex}"
    link = f"tg://proxy?server={custom_ip}&port={port}&secret={full_secret}"
    
    return {"link": link}

@app.get("/api/settings")
async def get_settings():
    """Получение настроек"""
    settings = parse_settings()
    return {
        "port": int(settings.get("PROXY_PORT", 443)),
        "domain": settings.get("PROXY_DOMAIN", "cloudflare.com"),
        "ad_tag": settings.get("AD_TAG", ""),
        "masking_enabled": settings.get("MASKING_ENABLED", "true") == "true",
        "custom_ip": settings.get("CUSTOM_IP", ""),
        "proxy_protocol": settings.get("PROXY_PROTOCOL", "false") == "true",
    }

@app.put("/api/settings")
async def update_settings(settings: SettingsUpdate):
    """Обновление настроек"""
    current = parse_settings()
    
    # Обновление значений
    if settings.port is not None:
        current["PROXY_PORT"] = str(settings.port)
    if settings.domain:
        current["PROXY_DOMAIN"] = settings.domain
    if settings.ad_tag is not None:
        current["AD_TAG"] = settings.ad_tag
    if settings.masking_enabled is not None:
        current["MASKING_ENABLED"] = "true" if settings.masking_enabled else "false"
    
    # Сохранение
    try:
        INSTALL_DIR.mkdir(parents=True, exist_ok=True)
        with open(SETTINGS_FILE, "w") as f:
            f.write(f"# MTProxyMax Settings — v1.0.4\n")
            f.write(f"# Generated by Web Interface\n\n")
            for key, value in current.items():
                f.write(f"{key}='{value}'\n")
        
        return {"success": True, "message": "Настройки сохранены"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/engine/start")
async def start_engine():
    """Запуск движка"""
    result = run_command(["start"])
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("stderr", "Failed to start engine"))
    
    return {"success": True, "message": "Движок запущен"}

@app.post("/api/engine/stop")
async def stop_engine():
    """Остановка движка"""
    result = run_command(["stop"])
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("stderr", "Failed to stop engine"))
    
    return {"success": True, "message": "Движок остановлен"}

@app.post("/api/engine/restart")
async def restart_engine():
    """Перезапуск движка"""
    result = run_command(["restart"])
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("stderr", "Failed to restart engine"))
    
    return {"success": True, "message": "Движок перезапущен"}

@app.get("/api/engine/status")
async def engine_status():
    """Статус движка"""
    return get_engine_status()

@app.get("/api/logs")
async def get_logs(lines: int = 100):
    """Получение логов"""
    log_file = INSTALL_DIR / "mtproxy.log"
    
    if not log_file.exists():
        return {"logs": []}
    
    try:
        with open(log_file, "r") as f:
            all_lines = f.readlines()
            last_lines = all_lines[-lines:] if len(all_lines) > lines else all_lines
        
        return {"logs": [line.strip() for line in last_lines]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════
if __name__ == "__main__":
    import uvicorn
    
    # Создание директорий если не существуют
    TEMPLATES_DIR.mkdir(parents=True, exist_ok=True)
    STATIC_DIR.mkdir(parents=True, exist_ok=True)
    
    uvicorn.run(app, host="0.0.0.0", port=8080)
