#!/bin/bash
# ==========================================================
# SKRYPT KONFIGURACJI WIZUALNEJ GNOME
# ==========================================================

set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

detect_system_lang() {
    local sys_lang="${LANG:-}"
    [[ -z "$sys_lang" ]] && sys_lang="${LC_ALL:-${LC_MESSAGES:-}}"
    if [[ "$sys_lang" == pl_PL* || "$sys_lang" == pl* ]]; then
        echo "pl"
    else
        echo "en"
    fi
}
SCRIPT_LANG="$(detect_system_lang)"

INFO='\033[0;34m'
SUCCESS='\033[0;32m'
WARN='\033[0;33m'
ERR='\033[0;31m'
NC='\033[0m'

TMP_LOG="$(mktemp /tmp/gnome-install-log.XXXXXX)"
LOG_FILE="$HOME/install_error_$(date +%Y%m%d_%H%M%S).log"

exec 3>&1
exec >>"$TMP_LOG" 2>&1

cleanup_on_exit() {
    local exit_code=$?
    printf '\033[?7h' >&3
    if [ "$exit_code" -ne 0 ]; then
        echo -e "\n" >&3
        cp -f "$TMP_LOG" "$LOG_FILE" 2>/dev/null || true
        if [[ "$SCRIPT_LANG" == "pl" ]]; then
            echo -e "${ERR}✘ Wystąpił błąd (kod: $exit_code). Szczegółowy log zapisano w: $LOG_FILE${NC}" >&3
        else
            echo -e "${ERR}✘ An error occurred (code: $exit_code). Detailed log saved to: $LOG_FILE${NC}" >&3
        fi
    fi
    sudo rm -f /etc/sudoers.d/99-temp-installer 2>/dev/null || true
    rm -f "$TMP_LOG" 2>/dev/null || true
}
trap cleanup_on_exit EXIT

_pick_msg() { [[ "$SCRIPT_LANG" == "pl" ]] && echo "$1" || echo "$2"; }
log_info()  { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${INFO}==> $m${NC}"; }
log_ok()    { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${SUCCESS}✔ $m${NC}"; }
log_err()   { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${ERR}✘ ERROR: $m${NC}"; }
log_warn()  { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${WARN}⚠ WARN: $m${NC}"; }

trap 'log_err "Błąd w linii $LINENO. Polecenie: $BASH_COMMAND" "Error at line $LINENO. Command: $BASH_COMMAND"' ERR

show_progress() {
    local step=$1
    local total=$2
    local msg=$3
    local percent=$(( step * 100 / total ))

    local cols
    cols=$(tput cols 2>/dev/null)
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=80

    local bar_width=50
    local reserved=12
    if (( cols - reserved < bar_width )); then
        bar_width=$(( cols - reserved ))
        (( bar_width < 10 )) && bar_width=10
    fi

    local overhead=$(( bar_width + reserved ))
    local avail=$(( cols - overhead ))
    if (( avail < 5 )); then avail=5; fi
    if (( ${#msg} > avail )); then
        msg="${msg:0:$((avail - 1))}…"
    fi

    local filled=$(( percent * bar_width / 100 ))
    local empty=$(( bar_width - filled ))

    local bar_filled=""
    local bar_empty=""
    if [ $filled -gt 0 ]; then printf -v bar_filled '%*s' "$filled" ''; bar_filled="${bar_filled// /#}"; fi
    if [ $empty -gt 0 ]; then printf -v bar_empty '%*s' "$empty" ''; bar_empty="${bar_empty// /-}"; fi

    printf "\r\033[K[\033[1;32m%s\033[0;90m%s\033[0m] %3d%% | \033[1;36m%s\033[0m" "$bar_filled" "$bar_empty" "$percent" "$msg" >&3
}

if [[ "$SCRIPT_LANG" == "pl" ]]; then
    MSG_PHASE_1="[1/3] Wykrywanie dystrybucji i konfiguracja uprawnień..."
    MSG_PHASE_2="[2/3] Instalacja i weryfikacja pakietów GNOME..."
    MSG_PHASE_3="[3/3] Konfiguracja środowiska, tapety i ustawień wizualnych..."
else
    MSG_PHASE_1="[1/3] Detecting distribution and configuring permissions..."
    MSG_PHASE_2="[2/3] Installing and verifying GNOME packages..."
    MSG_PHASE_3="[3/3] Configuring environment, wallpaper, and visual settings..."
fi

TOTAL_STEPS=11

CURRENT_USER=$(whoami)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
USER_PICTURES="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallpaper_PATH="$USER_PICTURES/wallpaper.jpg"
LOGIN_WALLPAPER_PATH="/usr/share/backgrounds/custom/login-wallpaper.png"

if [[ "$EUID" -eq 0 ]]; then
    echo -e "${ERR}✘ Nie uruchamiaj skryptu jako root. Uruchom jako zwykły użytkownik z sudo.${NC}" >&3
    exit 1
fi

sudo -v
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/99-temp-installer > /dev/null

# ==========================================================
# 1. WSTĘPNE SPRAWDZENIA I UPRAWNIENIA
# ==========================================================
show_progress 0 $TOTAL_STEPS "$MSG_PHASE_1"

printf '\033[?7h' >&3

printf '\033[?7l' >&3

show_progress 1 $TOTAL_STEPS "$MSG_PHASE_1"

# ==========================================================
# 2. WYKRYWANIE DYSTRYBUCJI I INSTALACJA PAKIETÓW
# ==========================================================
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS="${ID:-}"
        OS_LIKE="${ID_LIKE:-}"
    else
        OS="unknown"
        OS_LIKE=""
    fi
}

install_gnome_packages() {
    if [[ "$OS" == *"ubuntu"* || "$OS" == *"debian"* || "$OS_LIKE" == *"ubuntu"* || "$OS_LIKE" == *"debian"* || "$OS" == *"pop"* || "$OS" == *"linuxmint"* ]]; then
        sudo apt-get update -yq || true
        for pkg in gnome-tweaks gnome-shell-extension-prefs gnome-shell-extensions; do
            sudo apt-get install -yq "$pkg" || true
        done
    elif [[ "$OS" == "fedora" || "$OS_LIKE" == *"fedora"* ]]; then
        for pkg in gnome-tweaks gnome-extensions-app; do
            sudo dnf install -yq "$pkg" || true
        done
    elif [[ "$OS" == "arch" || "$OS_LIKE" == *"arch"* || "$OS" == "manjaro" ]]; then
        for pkg in gnome-tweaks gnome-shell-extensions; do
            sudo pacman -S --noconfirm --needed "$pkg" || true
        done
    elif [[ "$OS" == *"opensuse"* || "$OS" == *"suse"* || "$OS_LIKE" == *"suse"* ]]; then
        for pkg in gnome-tweaks gnome-shell-extensions; do
            sudo zypper install -yqn "$pkg" || true
        done
    fi
}

patch_gdm_login_background() {
    local wallpaper_path="$1"
    local gresource_path=""
    local candidate

    for candidate in \
        /usr/share/gnome-shell/gnome-shell-theme.gresource \
        /usr/share/themes/*/gnome-shell/gnome-shell-theme.gresource \
        /usr/share/gnome-shell/theme/gnome-shell-theme.gresource; do
        if [[ -f "$candidate" ]]; then
            gresource_path="$candidate"
            break
        fi
    done

    [[ -z "$gresource_path" ]] && return 0

    if ! command -v gresource >/dev/null 2>&1 || ! command -v glib-compile-resources >/dev/null 2>&1; then
        if [[ "$OS" == *"ubuntu"* || "$OS" == *"debian"* || "$OS_LIKE" == *"ubuntu"* || "$OS_LIKE" == *"debian"* || "$OS" == *"pop"* || "$OS" == *"linuxmint"* ]]; then
            sudo apt-get install -yq libglib2.0-bin || true
        elif [[ "$OS" == "fedora" || "$OS_LIKE" == *"fedora"* ]]; then
            sudo dnf install -yq glib2 || true
        elif [[ "$OS" == "arch" || "$OS_LIKE" == *"arch"* || "$OS" == "manjaro" ]]; then
            sudo pacman -S --noconfirm --needed glib2 || true
        elif [[ "$OS" == *"opensuse"* || "$OS" == *"suse"* || "$OS_LIKE" == *"suse"* ]]; then
            sudo zypper install -yqn glib2-tools || true
        fi
    fi

    if ! command -v gresource >/dev/null 2>&1 || ! command -v glib-compile-resources >/dev/null 2>&1; then
        return 0
    fi

    local backup_path="${gresource_path}.orig-backup"
    if [[ ! -f "$backup_path" ]]; then
        sudo cp -af "$gresource_path" "$backup_path" || true
    fi

    local work_dir
    work_dir="$(mktemp -d /tmp/gdm-theme-patch.XXXXXX)"
    local extract_root="$work_dir/extract"
    mkdir -p "$extract_root"

    local res list_file="$work_dir/list.txt"
    gresource list "$gresource_path" > "$list_file" 2>/dev/null || true

    if [[ ! -s "$list_file" ]]; then
        rm -rf "$work_dir"
        return 0
    fi

    while IFS= read -r res; do
        [[ -z "$res" ]] && continue
        mkdir -p "$extract_root/$(dirname "$res")"
        gresource extract "$gresource_path" "$res" > "$extract_root$res" 2>/dev/null || true
    done < "$list_file"

    local css_file
    css_file="$(find "$extract_root" -name "gnome-shell.css" | head -n1)"

    if [[ -z "$css_file" || ! -f "$css_file" ]]; then
        rm -rf "$work_dir"
        return 0
    fi

    local theme_dir
    theme_dir="$(dirname "$css_file")"
    cp -af "$wallpaper_path" "$theme_dir/login-wallpaper.png"

    if ! grep -q "login-wallpaper.png" "$css_file"; then
        python3 - "$css_file" <<'PYEOF' || true
import re, sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    css = f.read()

pattern = re.compile(r"#lockDialogGroup\s*\{[^}]*\}", re.DOTALL)
new_rule = (
    "#lockDialogGroup {\n"
    "  background: #2e3436 url(\"login-wallpaper.png\");\n"
    "  background-size: cover;\n"
    "  background-repeat: no-repeat;\n"
    "  background-position: center;\n"
    "}"
)

if pattern.search(css):
    css = pattern.sub(new_rule, css, count=1)
else:
    css += "\n" + new_rule + "\n"

with open(path, "w", encoding="utf-8") as f:
    f.write(css)
PYEOF
    fi

    local xml_file="$work_dir/gnome-shell-theme.gresource.xml"
    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<gresources>'
        echo '  <gresource prefix="/">'
        while IFS= read -r res; do
            [[ -z "$res" ]] && continue
            echo "    <file>${res#/}</file>"
        done < "$list_file"
        echo '  </gresource>'
        echo '</gresources>'
    } > "$xml_file"

    local compiled="$work_dir/gnome-shell-theme.gresource"
    if (cd "$extract_root" && glib-compile-resources --sourcedir="$extract_root" --target="$compiled" "$xml_file") 2>/dev/null; then
        sudo cp -af "$compiled" "$gresource_path" || true
    else
        sudo cp -af "$backup_path" "$gresource_path" || true
    fi

    rm -rf "$work_dir"
}

detect_os
show_progress 2 $TOTAL_STEPS "$MSG_PHASE_2"

install_gnome_packages
show_progress 3 $TOTAL_STEPS "$MSG_PHASE_2"

# ==========================================================
# 3. KONFIGURACJA WIZUALNA GNOME (pliki, wallpaper, rozszerzenia, avatar)
# ==========================================================
show_progress 4 $TOTAL_STEPS "$MSG_PHASE_3"

if [[ -d "$SCRIPT_DIR/.config" ]]; then cp -af "$SCRIPT_DIR/.config/." ~/.config/ || true; fi
if [[ -d "$SCRIPT_DIR/.local" ]]; then cp -af "$SCRIPT_DIR/.local/." ~/.local/ || true; fi

if [[ -d "$SCRIPT_DIR/.local/share" ]]; then
    mkdir -p ~/.local/share
    cp -af "$SCRIPT_DIR/.local/share/." ~/.local/share/ || true
fi

if [[ -d "$SCRIPT_DIR/.icons" ]]; then
    mkdir -p ~/.icons
    cp -af "$SCRIPT_DIR/.icons/." ~/.icons/ || true
fi

if [[ -f "$SCRIPT_DIR/wallpaper.jpg" ]]; then
    mkdir -p "$(dirname "$wallpaper_PATH")"
    cp -af "$SCRIPT_DIR/wallpaper.jpg" "$wallpaper_PATH" || true
fi

show_progress 5 $TOTAL_STEPS "$MSG_PHASE_3"

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper_PATH" 2>/dev/null \
        && gsettings set org.gnome.desktop.background picture-uri-dark "file://$wallpaper_PATH" 2>/dev/null \
        && gsettings set org.gnome.desktop.background picture-options "zoom" 2>/dev/null || true

    gsettings set org.gnome.desktop.screensaver picture-uri "file://$LOGIN_WALLPAPER_PATH" 2>/dev/null || true
    gsettings set org.gnome.desktop.screensaver picture-uri-dark "file://$LOGIN_WALLPAPER_PATH" 2>/dev/null || true
    gsettings set org.gnome.desktop.screensaver picture-options "zoom" 2>/dev/null || true
fi

show_progress 6 $TOTAL_STEPS "$MSG_PHASE_3"

if [[ -f "$SCRIPT_DIR/login-wallpaper.png" ]]; then
    sudo mkdir -p /usr/share/backgrounds/custom || true
    sudo cp -af "$SCRIPT_DIR/login-wallpaper.png" "$LOGIN_WALLPAPER_PATH" || true
    sudo chmod 755 /usr/share/backgrounds/custom || true
    sudo chmod 644 "$LOGIN_WALLPAPER_PATH" || true

    patch_gdm_login_background "$LOGIN_WALLPAPER_PATH"
fi

show_progress 7 $TOTAL_STEPS "$MSG_PHASE_3"

if [[ -f "$SCRIPT_DIR/dconf-settings.ini" ]]; then
    if command -v dconf &>/dev/null; then
        sed 's/\r$//' "$SCRIPT_DIR/dconf-settings.ini" > /tmp/dconf-settings.ini.tmp && mv /tmp/dconf-settings.ini.tmp "$SCRIPT_DIR/dconf-settings.ini"

        mkdir -p "$HOME/.config/dconf"

        dconf load / < "$SCRIPT_DIR/dconf-settings.ini" || true
    fi
fi

show_progress 8 $TOTAL_STEPS "$MSG_PHASE_3"

if command -v pipx &>/dev/null; then
    pipx install gnome-extensions-cli --force || true

    GEXT_CMD="$HOME/.local/bin/gext"
    if command -v gext &>/dev/null; then
        GEXT_CMD="gext"
    fi

    if [[ -x "$GEXT_CMD" ]] || command -v gext &>/dev/null; then
        for ext in \
            blur-my-shell@aunetx \
            clipboard-history@alexsaveau.dev \
            compiz-alike-magic-lamp-effect@hermes83.github.com \
            compiz-windows-effect@hermes83.github.com \
            dash-to-dock@micxgx.gmail.com \
            netspeedindicator@subashghimire.info.np \
            weatherpanel@attentivecoder; do
            "$GEXT_CMD" install "$ext" || true
        done
    fi
fi

show_progress 9 $TOTAL_STEPS "$MSG_PHASE_3"

if [[ -f "$SCRIPT_DIR/piwo.png" ]]; then
    AVATAR_DEST="/var/lib/AccountsService/icons/$CURRENT_USER"
    sudo mkdir -p "$(dirname "$AVATAR_DEST")" || true
    sudo cp -af "$SCRIPT_DIR/piwo.png" "$AVATAR_DEST" || true
    sudo chmod 644 "$AVATAR_DEST" || true

    ACCOUNTS_FILE="/var/lib/AccountsService/users/$CURRENT_USER"
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        if sudo grep -q "^Icon=" "$ACCOUNTS_FILE"; then
            sudo sed -i "s|^Icon=.*|Icon=$AVATAR_DEST|" "$ACCOUNTS_FILE" || true
        elif sudo grep -q "^\[User\]" "$ACCOUNTS_FILE"; then
            sudo sed -i "/^\[User\]/a Icon=$AVATAR_DEST" "$ACCOUNTS_FILE" || true
        else
            echo "Icon=$AVATAR_DEST" | sudo tee -a "$ACCOUNTS_FILE" > /dev/null
        fi
    else
        echo -e "[User]\nIcon=$AVATAR_DEST" | sudo tee "$ACCOUNTS_FILE" > /dev/null
    fi
fi

show_progress 10 $TOTAL_STEPS "$MSG_PHASE_3"

# ==========================================================
# 4. ZAKOŃCZENIE I SPRZĄTANIE
# ==========================================================
sudo rm -f /etc/sudoers.d/99-temp-installer

show_progress 11 $TOTAL_STEPS "$MSG_PHASE_3"
echo -e "\n" >&3

if [[ "$SCRIPT_LANG" == "pl" ]]; then
    echo -e "${SUCCESS}✔ KONFIGURACJA WIZUALNA ZAKOŃCZONA!${NC}" >&3
else
    echo -e "${SUCCESS}✔ VISUAL CONFIGURATION COMPLETED!${NC}" >&3
fi

systemctl reboot
