#!/bin/bash
# ==========================================================
# SKRYPT KONFIGURACJI WIZUALNEJ GNOME
# ==========================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- Kolory i logowanie ---
INFO='\033[0;34m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
WARN='\033[0;33m'
NC='\033[0m'

log_info() { echo -e "${INFO}==> $*${NC}"; }
log_ok()   { echo -e "${SUCCESS}✔ $*${NC}"; }
log_err()  { echo -e "${ERROR}✖ BŁĄD: $*${NC}" >&2; }
log_warn() { echo -e "${WARN}⚠ UWAGA: $*${NC}"; }

trap 'log_err "Błąd w linii $LINENO. Polecenie: $BASH_COMMAND"' ERR

# --- Zmienne globalne ---
CURRENT_USER=$(whoami)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
wallpaper_PATH="/home/$CURRENT_USER/Obrazy/wallpaper.jpg"
LOGIN_WALLPAPER_PATH="/usr/share/backgrounds/custom/login-wallpaper.png"

# --- Sprawdzenie uprawnień ---
if [[ "$EUID" -eq 0 ]]; then
    log_err "Nie uruchamiaj skryptu jako root. Użyj zwykłego użytkownika z dostępem do sudo."
    exit 1
fi

# ==========================================================
# DETEKCJA OS I INSTALACJA GNOME TWEAKS ORAZ EXTENSIONS
# ==========================================================
log_info "Wykrywanie dystrybucji i instalacja GNOME Tweaks oraz Extensions..."

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS="${ID:-}"
    OS_LIKE="${ID_LIKE:-}"
else
    log_warn "Brak pliku /etc/os-release. Pomijam automatyczną instalację pakietów."
    OS="unknown"
    OS_LIKE=""
fi

if [[ "$OS" == *"ubuntu"* || "$OS" == *"debian"* || "$OS_LIKE" == *"ubuntu"* || "$OS_LIKE" == *"debian"* || "$OS" == *"pop"* || "$OS" == *"linuxmint"* ]]; then
    sudo apt-get update -yq
    sudo apt-get install -yq gnome-tweaks gnome-shell-extension-prefs gnome-shell-extensions
elif [[ "$OS" == "fedora" || "$OS_LIKE" == *"fedora"* ]]; then
    sudo dnf install -yq gnome-tweaks gnome-extensions-app
elif [[ "$OS" == "arch" || "$OS_LIKE" == *"arch"* || "$OS" == "manjaro" ]]; then
    sudo pacman -S --noconfirm --needed gnome-tweaks gnome-shell-extensions
elif [[ "$OS" == *"opensuse"* || "$OS" == *"suse"* || "$OS_LIKE" == *"suse"* ]]; then
    sudo zypper install -yqn gnome-tweaks gnome-shell-extensions
else
    log_warn "Nierozpoznana dystrybucja ($OS / $OS_LIKE). Zainstaluj pakiety ręcznie."
fi

log_ok "Instalacja pakietów systemowych zakończona."


# ==========================================================
# KONFIGURACJA WIZUALNA GNOME (pliki, wallpaper, rozszerzenia, avatar)
# ==========================================================
log_info "Kopiowanie plików konfiguracyjnych..."
if [[ -d "$SCRIPT_DIR/.config" ]]; then cp -af "$SCRIPT_DIR/.config/." ~/.config/; fi
if [[ -d "$SCRIPT_DIR/.local" ]]; then cp -af "$SCRIPT_DIR/.local/." ~/.local/; fi

# --- Dedykowane kopiowanie .local/share ---
if [[ -d "$SCRIPT_DIR/.local/share" ]]; then
    log_info "Kopiowanie zawartości .local/share..."
    mkdir -p ~/.local/share
    cp -af "$SCRIPT_DIR/.local/share/." ~/.local/share/
fi

# --- Dedykowane kopiowanie .icons ---
if [[ -d "$SCRIPT_DIR/.icons" ]]; then
    log_info "Kopiowanie zawartości .icons do katalogu domowego..."
    mkdir -p ~/.icons
    cp -af "$SCRIPT_DIR/.icons/." ~/.icons/
fi

# --- Kopiowanie tapety pulpitu ---
if [[ -f "$SCRIPT_DIR/wallpaper.jpg" ]]; then
    mkdir -p "$(dirname "$wallpaper_PATH")"
    cp -af "$SCRIPT_DIR/wallpaper.jpg" "$wallpaper_PATH"
fi

# --- Ustawienie tapety w GNOME (gsettings) ---
if command -v gsettings >/dev/null 2>&1; then
    log_info "Ustawiam tapetę pulpitu w systemie GNOME..."

    if gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper_PATH" 2>/dev/null \
        && gsettings set org.gnome.desktop.background picture-uri-dark "file://$wallpaper_PATH" 2>/dev/null \
        && gsettings set org.gnome.desktop.background picture-options "zoom" 2>/dev/null; then
        log_ok "Tapeta pulpitu GNOME została zaktualizowana."
    else
        log_warn "Nie udało się ustawić tapety GNOME."
    fi

    gsettings set org.gnome.desktop.screensaver picture-uri "file://$LOGIN_WALLPAPER_PATH" 2>/dev/null || true
    gsettings set org.gnome.desktop.screensaver picture-uri-dark "file://$LOGIN_WALLPAPER_PATH" 2>/dev/null || true
    gsettings set org.gnome.desktop.screensaver picture-options "zoom" 2>/dev/null || true
else
    log_warn "gsettings nie znaleziony — pomijam automatyczną zmianę tapety."
fi

# --- Ekran logowania (GDM) ---
log_info "Ustawianie tła ekranu logowania GDM przez dconf..."

if [[ -f "$SCRIPT_DIR/login-wallpaper.png" ]]; then
    sudo mkdir -p /usr/share/backgrounds/custom
    sudo cp -af "$SCRIPT_DIR/login-wallpaper.png" "$LOGIN_WALLPAPER_PATH"
    sudo chmod 755 /usr/share/backgrounds/custom
    sudo chmod 644 "$LOGIN_WALLPAPER_PATH"

    sudo mkdir -p /etc/dconf/profile /etc/dconf/db/gdm.d

    if [[ ! -f /etc/dconf/profile/gdm ]]; then
        cat <<'EOF' | sudo tee /etc/dconf/profile/gdm > /dev/null
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF
    fi

    cat <<EOF | sudo tee /etc/dconf/db/gdm.d/01-login-background > /dev/null
[org/gnome/desktop/background]
picture-uri='file://$LOGIN_WALLPAPER_PATH'
picture-uri-dark='file://$LOGIN_WALLPAPER_PATH'
picture-options='zoom'
EOF

    if sudo dconf update; then
        log_ok "Tło ekranu logowania GDM zostało ustawione (dconf)."
    else
        log_err "Błąd podczas 'dconf update' dla bazy gdm."
    fi
else
    log_warn "Nie znaleziono pliku login-wallpaper.png — pomijam tapetę ekranu logowania."
fi

# --- Wczytanie ustawień dconf (bez sudo, w kontekście użytkownika) ---
if [[ -f "$SCRIPT_DIR/dconf-settings.ini" ]]; then
    if command -v dconf &>/dev/null; then
        log_info "Czyszczenie pliku INI..."
        sed -i 's/\r$//' "$SCRIPT_DIR/dconf-settings.ini"

        mkdir -p "$HOME/.config/dconf"

        log_info "Wczytywanie ustawień dconf dla użytkownika $CURRENT_USER..."

        if dconf load / < "$SCRIPT_DIR/dconf-settings.ini"; then
            log_ok "Wczytano ustawienia dconf pomyślnie!"
        else
            log_err "Błąd podczas ładowania ustawień dconf."
        fi
    else
        log_warn "Polecenie 'dconf' jest niedostępne — pomijam wczytywanie."
    fi
else
    log_warn "Nie znaleziono dconf-settings.ini — pomijam wczytywanie."
fi

# --- Instalacja rozszerzeń GNOME ---
log_info "Instalacja narzędzia gnome-extensions-cli oraz rozszerzeń GNOME..."
if command -v pipx &>/dev/null; then
    pipx install gnome-extensions-cli --force || true

    GEXT_CMD="$HOME/.local/bin/gext"
    if command -v gext &>/dev/null; then
        GEXT_CMD="gext"
    fi

    if [[ -x "$GEXT_CMD" ]] || command -v gext &>/dev/null; then
        log_info "Pobieranie i aktywacja rozszerzeń GNOME..."
        "$GEXT_CMD" install \
            blur-my-shell@aunetx \
            clipboard-history@alexsaveau.dev \
            compiz-alike-magic-lamp-effect@hermes83.github.com \
            compiz-windows-effect@hermes83.github.com \
            dash-to-dock@micxgx.gmail.com \
            netspeedindicator@subashghimire.info.np \
            weatherpanel@attentivecoder || log_warn "Niektóre rozszerzenia mogły wymagać ponownego zalogowania do aktywacji."
        log_ok "Instalacja rozszerzeń GNOME zakończona."
    else
        log_warn "Nie udało się zlokalizować 'gext' w ścieżce wywoływalnej — pomijam rozszerzenia."
    fi
else
    log_warn "Brak zainstalowanego 'pipx' — pomijam instalację rozszerzeń GNOME."
fi

# --- Avatar użytkownika ---
if [[ -f "$SCRIPT_DIR/piwo.png" ]]; then
    log_info "Ustawiam avatar użytkownika..."
    AVATAR_DEST="/var/lib/AccountsService/icons/$CURRENT_USER"
    sudo mkdir -p "$(dirname "$AVATAR_DEST")"
    sudo cp -af "$SCRIPT_DIR/piwo.png" "$AVATAR_DEST"
    sudo chmod 644 "$AVATAR_DEST"

    ACCOUNTS_FILE="/var/lib/AccountsService/users/$CURRENT_USER"
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        if sudo grep -q "^Icon=" "$ACCOUNTS_FILE"; then
            sudo sed -i "s|^Icon=.*|Icon=$AVATAR_DEST|" "$ACCOUNTS_FILE"
        elif sudo grep -q "^\[User\]" "$ACCOUNTS_FILE"; then
            sudo sed -i "/^\[User\]/a Icon=$AVATAR_DEST" "$ACCOUNTS_FILE"
        else
            echo "Icon=$AVATAR_DEST" | sudo tee -a "$ACCOUNTS_FILE" > /dev/null
        fi
    else
        echo -e "[User]\nIcon=$AVATAR_DEST" | sudo tee "$ACCOUNTS_FILE" > /dev/null
    fi
    log_ok "Avatar użytkownika został ustawiony."
else
    log_warn "Nie znaleziono pliku piwo.png — pomijam ustawienie avatara."
fi

log_ok "KONFIGURACJA WIZUALNA ZAKOŃCZONA!"
systemctl reboot
