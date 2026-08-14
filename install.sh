#!/bin/bash
# ==========================================================
# SKRYPT KONFIGURACJI WIZUALNEJ GNOME
# ==========================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ── Wykrywanie języka systemu ──────────────────────────────────
# Jeśli system jest ustawiony na polski (pl_PL/pl_*) -> komunikaty PL,
# w każdym innym przypadku -> komunikaty EN.
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

# ── Kolory ────────────────────────────────────────────────────
INFO='\033[0;34m'
SUCCESS='\033[0;32m'
WARN='\033[0;33m'
ERR='\033[0;31m'
NC='\033[0m'

# ── System logowania w tle ─────────────────────────────────────
# Zasada: na ekranie widoczne są TYLKO ważne komunikaty ogólne (log_info / log_ok / log_error).
# Wszystko inne (log_warn, wyjście poleceń itp.) trafia WYŁĄCZNIE do pliku logu.
TMP_LOG="$(mktemp /tmp/gnome-config-log.XXXXXX)"
LOG_FILE="$HOME/gnome_config_error_$(date +%Y%m%d_%H%M%S).log"

# fd 3 = prawdziwy terminal
exec 3>&1
exec >>"$TMP_LOG" 2>&1

cleanup_on_exit() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        cp -f "$TMP_LOG" "$LOG_FILE" 2>/dev/null || true
        if [[ "$SCRIPT_LANG" == "pl" ]]; then
            echo -e "${ERR}✘ Wystąpił błąd (kod: $exit_code). Szczegółowy log zapisano w: $LOG_FILE${NC}" >&3
        else
            echo -e "${ERR}✘ An error occurred (code: $exit_code). Detailed log saved to: $LOG_FILE${NC}" >&3
        fi
    fi
    rm -f "$TMP_LOG"
}
trap cleanup_on_exit EXIT

# ── Pomocnicze funkcje logowania ──────────────────────────────
_pick_msg() { [[ "$SCRIPT_LANG" == "pl" ]] && echo "$1" || echo "$2"; }

log_info()  { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${INFO}==> $m${NC}" >&3; echo -e "${INFO}==> $m${NC}"; }
log_ok()    { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${SUCCESS}✔ $m${NC}" >&3; echo -e "${SUCCESS}✔ $m${NC}"; }
log_error() { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${ERR}✘ $m${NC}" >&3; echo -e "${ERR}✘ $m${NC}"; }
# log_warn celowo NIE trafia na ekran (fd 3) - tylko do logu
log_warn()  { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${WARN}⚠ $m${NC}"; }

# --- Zmienne globalne ---
CURRENT_USER=$(whoami)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
# Użycie domyślnego katalogu Pictures/Obrazy w zależności od istnienia
USER_PICTURES="$HOME/Obrazy"
[[ -d "$HOME/Pictures" ]] && USER_PICTURES="$HOME/Pictures"
wallpaper_PATH="$USER_PICTURES/wallpaper.jpg"
LOGIN_WALLPAPER_PATH="/usr/share/backgrounds/custom/login-wallpaper.png"

# --- Sprawdzenie uprawnień ---
if [[ "$EUID" -eq 0 ]]; then
    log_error "Nie uruchamiaj skryptu jako root. Użyj zwykłego użytkownika z dostępem do sudo." \
              "Do not run this script as root. Use a regular user with sudo access."
    exit 1
fi

# ==========================================================
# BUFOROWANIE UPRAWNIEŃ SUDO
# ==========================================================
sudo -v

# ==========================================================
# DETEKCJA OS I INSTALACJA GNOME TWEAKS ORAZ EXTENSIONS
# ==========================================================
log_info "Wykrywanie dystrybucji i instalacja GNOME Tweaks oraz Extensions..." \
         "Detecting distribution and installing GNOME Tweaks and Extensions..."

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS="${ID:-}"
    OS_LIKE="${ID_LIKE:-}"
else
    log_warn "Brak pliku /etc/os-release. Pomijam automatyczną instalację pakietów." \
             "Missing /etc/os-release file. Skipping automatic package installation."
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
    log_warn "Nierozpoznana dystrybucja ($OS / $OS_LIKE). Zainstaluj pakiety ręcznie." \
             "Unrecognized distribution ($OS / $OS_LIKE). Install packages manually."
fi

log_ok "Instalacja pakietów systemowych zakończona." \
       "System packages installation completed."


# ==========================================================
# KONFIGURACJA WIZUALNA GNOME (pliki, wallpaper, rozszerzenia, avatar)
# ==========================================================
log_info "Kopiowanie plików konfiguracyjnych..." \
         "Copying configuration files..."

if [[ -d "$SCRIPT_DIR/.config" ]]; then cp -af "$SCRIPT_DIR/.config/." ~/.config/; fi
if [[ -d "$SCRIPT_DIR/.local" ]]; then cp -af "$SCRIPT_DIR/.local/." ~/.local/; fi

# --- Dedykowane kopiowanie .local/share ---
if [[ -d "$SCRIPT_DIR/.local/share" ]]; then
    log_info "Kopiowanie zawartości .local/share..." \
             "Copying .local/share contents..."
    mkdir -p ~/.local/share
    cp -af "$SCRIPT_DIR/.local/share/." ~/.local/share/
fi

# --- Dedykowane kopiowanie .icons ---
if [[ -d "$SCRIPT_DIR/.icons" ]]; then
    log_info "Kopiowanie zawartości .icons do katalogu domowego..." \
             "Copying .icons contents to home directory..."
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
    log_info "Ustawiam tapetę pulpitu w systemie GNOME..." \
             "Setting desktop wallpaper in GNOME..."

    if gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper_PATH" 2>/dev/null \
        && gsettings set org.gnome.desktop.background picture-uri-dark "file://$wallpaper_PATH" 2>/dev/null \
        && gsettings set org.gnome.desktop.background picture-options "zoom" 2>/dev/null; then
        log_ok "Tapeta pulpitu GNOME została zaktualizowana." \
               "GNOME desktop wallpaper updated."
    else
        log_warn "Nie udało się ustawić tapety GNOME." \
                 "Failed to set GNOME wallpaper."
    fi

    gsettings set org.gnome.desktop.screensaver picture-uri "file://$LOGIN_WALLPAPER_PATH" 2>/dev/null || true
    gsettings set org.gnome.desktop.screensaver picture-uri-dark "file://$LOGIN_WALLPAPER_PATH" 2>/dev/null || true
    gsettings set org.gnome.desktop.screensaver picture-options "zoom" 2>/dev/null || true
else
    log_warn "gsettings nie znaleziony — pomijam automatyczną zmianę tapety." \
             "gsettings not found — skipping automatic wallpaper change."
fi

# --- Ekran logowania (GDM) ---
log_info "Ustawianie tła ekranu logowania GDM przez dconf..." \
         "Setting GDM login screen background via dconf..."

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
        log_ok "Tło ekranu logowania GDM zostało ustawione (dconf)." \
               "GDM login screen background set (dconf)."
    else
        log_error "Błąd podczas 'dconf update' dla bazy gdm." \
                  "Error during 'dconf update' for gdm database."
    fi
else
    log_warn "Nie znaleziono pliku login-wallpaper.png — pomijam tapetę ekranu logowania." \
             "login-wallpaper.png not found — skipping login screen wallpaper."
fi

# --- Wczytanie ustawień dconf (bez sudo, w kontekście użytkownika) ---
if [[ -f "$SCRIPT_DIR/dconf-settings.ini" ]]; then
    if command -v dconf &>/dev/null; then
        log_info "Czyszczenie pliku INI..." \
                 "Cleaning INI file..."
        sed -i 's/\r$//' "$SCRIPT_DIR/dconf-settings.ini"

        mkdir -p "$HOME/.config/dconf"

        log_info "Wczytywanie ustawień dconf dla użytkownika $CURRENT_USER..." \
                 "Loading dconf settings for user $CURRENT_USER..."

        if dconf load / < "$SCRIPT_DIR/dconf-settings.ini"; then
            log_ok "Wczytano ustawienia dconf pomyślnie!" \
                   "dconf settings loaded successfully!"
        else
            log_error "Błąd podczas ładowania ustawień dconf." \
                      "Error while loading dconf settings."
        fi
    else
        log_warn "Polecenie 'dconf' jest niedostępne — pomijam wczytywanie." \
                 "'dconf' command unavailable — skipping load."
    fi
else
    log_warn "Nie znaleziono dconf-settings.ini — pomijam wczytywanie." \
             "dconf-settings.ini not found — skipping load."
fi

# --- Instalacja rozszerzeń GNOME ---
log_info "Instalacja narzędzia gnome-extensions-cli oraz rozszerzeń GNOME..." \
         "Installing gnome-extensions-cli and GNOME extensions..."

if command -v pipx &>/dev/null; then
    pipx install gnome-extensions-cli --force || true

    GEXT_CMD="$HOME/.local/bin/gext"
    if command -v gext &>/dev/null; then
        GEXT_CMD="gext"
    fi

    if [[ -x "$GEXT_CMD" ]] || command -v gext &>/dev/null; then
        log_info "Pobieranie i aktywacja rozszerzeń GNOME..." \
                 "Downloading and activating GNOME extensions..."
        "$GEXT_CMD" install \
            blur-my-shell@aunetx \
            clipboard-history@alexsaveau.dev \
            compiz-alike-magic-lamp-effect@hermes83.github.com \
            compiz-windows-effect@hermes83.github.com \
            dash-to-dock@micxgx.gmail.com \
            netspeedindicator@subashghimire.info.np \
            weatherpanel@attentivecoder || log_warn "Niektóre rozszerzenia mogły wymagać ponownego zalogowania do aktywacji." \
                                                    "Some extensions may require a re-login to activate."
        log_ok "Instalacja rozszerzeń GNOME zakończona." \
               "GNOME extensions installation completed."
    else
        log_warn "Nie udało się zlokalizować 'gext' w ścieżce wywoływalnej — pomijam rozszerzenia." \
                 "Failed to locate 'gext' in PATH — skipping extensions."
    fi
else
    log_warn "Brak zainstalowanego 'pipx' — pomijam instalację rozszerzeń GNOME." \
             "'pipx' is not installed — skipping GNOME extensions installation."
fi

# --- Avatar użytkownika ---
if [[ -f "$SCRIPT_DIR/piwo.png" ]]; then
    log_info "Ustawiam avatar użytkownika..." \
             "Setting user avatar..."
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
    log_ok "Avatar użytkownika został ustawiony." \
           "User avatar set."
else
    log_warn "Nie znaleziono pliku piwo.png — pomijam ustawienie avatara." \
             "piwo.png not found — skipping avatar setup."
fi

log_ok "KONFIGURACJA WIZUALNA ZAKOŃCZONA!" \
       "VISUAL CONFIGURATION COMPLETED!"
#!/bin/bash
# ==========================================================
# SKRYPT KONFIGURACJI WIZUALNEJ GNOME
# ==========================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ── Wykrywanie języka systemu ──────────────────────────────────
# Jeśli system jest ustawiony na polski (pl_PL/pl_*) -> komunikaty PL,
# w każdym innym przypadku -> komunikaty EN.
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

# ── Kolory ────────────────────────────────────────────────────
INFO='\033[0;34m'
SUCCESS='\033[0;32m'
WARN='\033[0;33m'
ERR='\033[0;31m'
NC='\033[0m'

# ── System logowania w tle ─────────────────────────────────────
# Zasada: na ekranie widoczne są TYLKO ważne komunikaty ogólne (log_info / log_ok / log_error).
# Wszystko inne (log_warn, wyjście poleceń itp.) trafia WYŁĄCZNIE do pliku logu.
TMP_LOG="$(mktemp /tmp/gnome-config-log.XXXXXX)"
LOG_FILE="$HOME/gnome_config_error_$(date +%Y%m%d_%H%M%S).log"

# fd 3 = prawdziwy terminal
exec 3>&1
exec >>"$TMP_LOG" 2>&1

cleanup_on_exit() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        cp -f "$TMP_LOG" "$LOG_FILE" 2>/dev/null || true
        if [[ "$SCRIPT_LANG" == "pl" ]]; then
            echo -e "${ERR}✘ Wystąpił błąd (kod: $exit_code). Szczegółowy log zapisano w: $LOG_FILE${NC}" >&3
        else
            echo -e "${ERR}✘ An error occurred (code: $exit_code). Detailed log saved to: $LOG_FILE${NC}" >&3
        fi
    fi
    rm -f "$TMP_LOG"
}
trap cleanup_on_exit EXIT

# ── Pomocnicze funkcje logowania ──────────────────────────────
_pick_msg() { [[ "$SCRIPT_LANG" == "pl" ]] && echo "$1" || echo "$2"; }

log_info()  { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${INFO}==> $m${NC}" >&3; echo -e "${INFO}==> $m${NC}"; }
log_ok()    { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${SUCCESS}✔ $m${NC}" >&3; echo -e "${SUCCESS}✔ $m${NC}"; }
log_error() { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${ERR}✘ $m${NC}" >&3; echo -e "${ERR}✘ $m${NC}"; }
# log_warn celowo NIE trafia na ekran (fd 3) - tylko do logu
log_warn()  { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${WARN}⚠ $m${NC}"; }

# --- Zmienne globalne ---
CURRENT_USER=$(whoami)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
wallpaper_PATH="/home/$CURRENT_USER/Obrazy/wallpaper.jpg"
LOGIN_WALLPAPER_PATH="/usr/share/backgrounds/custom/login-wallpaper.png"

# --- Sprawdzenie uprawnień ---
if [[ "$EUID" -eq 0 ]]; then
    log_error "Nie uruchamiaj skryptu jako root. Użyj zwykłego użytkownika z dostępem do sudo." \
              "Do not run this script as root. Use a regular user with sudo access."
    exit 1
fi

# ==========================================================
# DETEKCJA OS I INSTALACJA GNOME TWEAKS ORAZ EXTENSIONS
# ==========================================================
log_info "Wykrywanie dystrybucji i instalacja GNOME Tweaks oraz Extensions..." \
         "Detecting distribution and installing GNOME Tweaks and Extensions..."

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS="${ID:-}"
    OS_LIKE="${ID_LIKE:-}"
else
    log_warn "Brak pliku /etc/os-release. Pomijam automatyczną instalację pakietów." \
             "Missing /etc/os-release file. Skipping automatic package installation."
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
    log_warn "Nierozpoznana dystrybucja ($OS / $OS_LIKE). Zainstaluj pakiety ręcznie." \
             "Unrecognized distribution ($OS / $OS_LIKE). Install packages manually."
fi

log_ok "Instalacja pakietów systemowych zakończona." \
       "System packages installation completed."


# ==========================================================
# KONFIGURACJA WIZUALNA GNOME (pliki, wallpaper, rozszerzenia, avatar)
# ==========================================================
log_info "Kopiowanie plików konfiguracyjnych..." \
         "Copying configuration files..."

if [[ -d "$SCRIPT_DIR/.config" ]]; then cp -af "$SCRIPT_DIR/.config/." ~/.config/; fi
if [[ -d "$SCRIPT_DIR/.local" ]]; then cp -af "$SCRIPT_DIR/.local/." ~/.local/; fi

# --- Dedykowane kopiowanie .local/share ---
if [[ -d "$SCRIPT_DIR/.local/share" ]]; then
    log_info "Kopiowanie zawartości .local/share..." \
             "Copying .local/share contents..."
    mkdir -p ~/.local/share
    cp -af "$SCRIPT_DIR/.local/share/." ~/.local/share/
fi

# --- Dedykowane kopiowanie .icons ---
if [[ -d "$SCRIPT_DIR/.icons" ]]; then
    log_info "Kopiowanie zawartości .icons do katalogu domowego..." \
             "Copying .icons contents to home directory..."
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
    log_info "Ustawiam tapetę pulpitu w systemie GNOME..." \
             "Setting desktop wallpaper in GNOME..."

    if gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper_PATH" 2>/dev/null \
        && gsettings set org.gnome.desktop.background picture-uri-dark "file://$wallpaper_PATH" 2>/dev/null \
        && gsettings set org.gnome.desktop.background picture-options "zoom" 2>/dev/null; then
        log_ok "Tapeta pulpitu GNOME została zaktualizowana." \
               "GNOME desktop wallpaper updated."
    else
        log_warn "Nie udało się ustawić tapety GNOME." \
                 "Failed to set GNOME wallpaper."
    fi

    gsettings set org.gnome.desktop.screensaver picture-uri "file://$LOGIN_WALLPAPER_PATH" 2>/dev/null || true
    gsettings set org.gnome.desktop.screensaver picture-uri-dark "file://$LOGIN_WALLPAPER_PATH" 2>/dev/null || true
    gsettings set org.gnome.desktop.screensaver picture-options "zoom" 2>/dev/null || true
else
    log_warn "gsettings nie znaleziony — pomijam automatyczną zmianę tapety." \
             "gsettings not found — skipping automatic wallpaper change."
fi

# --- Ekran logowania (GDM) ---
log_info "Ustawianie tła ekranu logowania GDM przez dconf..." \
         "Setting GDM login screen background via dconf..."

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
        log_ok "Tło ekranu logowania GDM zostało ustawione (dconf)." \
               "GDM login screen background set (dconf)."
    else
        log_error "Błąd podczas 'dconf update' dla bazy gdm." \
                  "Error during 'dconf update' for gdm database."
    fi
else
    log_warn "Nie znaleziono pliku login-wallpaper.png — pomijam tapetę ekranu logowania." \
             "login-wallpaper.png not found — skipping login screen wallpaper."
fi

# --- Wczytanie ustawień dconf (bez sudo, w kontekście użytkownika) ---
if [[ -f "$SCRIPT_DIR/dconf-settings.ini" ]]; then
    if command -v dconf &>/dev/null; then
        log_info "Czyszczenie pliku INI..." \
                 "Cleaning INI file..."
        sed -i 's/\r$//' "$SCRIPT_DIR/dconf-settings.ini"

        mkdir -p "$HOME/.config/dconf"

        log_info "Wczytywanie ustawień dconf dla użytkownika $CURRENT_USER..." \
                 "Loading dconf settings for user $CURRENT_USER..."

        if dconf load / < "$SCRIPT_DIR/dconf-settings.ini"; then
            log_ok "Wczytano ustawienia dconf pomyślnie!" \
                   "dconf settings loaded successfully!"
        else
            log_error "Błąd podczas ładowania ustawień dconf." \
                      "Error while loading dconf settings."
        fi
    else
        log_warn "Polecenie 'dconf' jest niedostępne — pomijam wczytywanie." \
                 "'dconf' command unavailable — skipping load."
    fi
else
    log_warn "Nie znaleziono dconf-settings.ini — pomijam wczytywanie." \
             "dconf-settings.ini not found — skipping load."
fi

# --- Instalacja rozszerzeń GNOME ---
log_info "Instalacja narzędzia gnome-extensions-cli oraz rozszerzeń GNOME..." \
         "Installing gnome-extensions-cli and GNOME extensions..."

if command -v pipx &>/dev/null; then
    pipx install gnome-extensions-cli --force || true

    GEXT_CMD="$HOME/.local/bin/gext"
    if command -v gext &>/dev/null; then
        GEXT_CMD="gext"
    fi

    if [[ -x "$GEXT_CMD" ]] || command -v gext &>/dev/null; then
        log_info "Pobieranie i aktywacja rozszerzeń GNOME..." \
                 "Downloading and activating GNOME extensions..."
        "$GEXT_CMD" install \
            blur-my-shell@aunetx \
            clipboard-history@alexsaveau.dev \
            compiz-alike-magic-lamp-effect@hermes83.github.com \
            compiz-windows-effect@hermes83.github.com \
            dash-to-dock@micxgx.gmail.com \
            netspeedindicator@subashghimire.info.np \
            weatherpanel@attentivecoder || log_warn "Niektóre rozszerzenia mogły wymagać ponownego zalogowania do aktywacji." \
                                                    "Some extensions may require a re-login to activate."
        log_ok "Instalacja rozszerzeń GNOME zakończona." \
               "GNOME extensions installation completed."
    else
        log_warn "Nie udało się zlokalizować 'gext' w ścieżce wywoływalnej — pomijam rozszerzenia." \
                 "Failed to locate 'gext' in PATH — skipping extensions."
    fi
else
    log_warn "Brak zainstalowanego 'pipx' — pomijam instalację rozszerzeń GNOME." \
             "'pipx' is not installed — skipping GNOME extensions installation."
fi

# --- Avatar użytkownika ---
if [[ -f "$SCRIPT_DIR/piwo.png" ]]; then
    log_info "Ustawiam avatar użytkownika..." \
             "Setting user avatar..."
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
    log_ok "Avatar użytkownika został ustawiony." \
           "User avatar set."
else
    log_warn "Nie znaleziono pliku piwo.png — pomijam ustawienie avatara." \
             "piwo.png not found — skipping avatar setup."
fi

log_ok "KONFIGURACJA WIZUALNA ZAKOŃCZONA!" \
       "VISUAL CONFIGURATION COMPLETED!"
systemctl reboot
