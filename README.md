# 🎨 GNOME Visual Configuration Script

An automated Bash shell script designed for complete visual and environment configuration of **GNOME** desktop across popular Linux distributions. The script automatically detects the system package manager, installs required utility tools (GNOME Tweaks, GNOME Extensions), copies user configurations (`.config`, `.local/share`), sets wallpapers (desktop + GDM login screen), loads `dconf` settings, and installs GNOME extensions.

---

## 🚀 Script Features

- **Automatic Linux Distribution Detection**: Full support for Debian, Ubuntu, Fedora, Arch Linux, openSUSE, and their derivatives.
- **GNOME Tools Installation**: Automatically installs `gnome-tweaks` and extension management tools depending on the distribution.
- **Configuration Files Sync**:
  - Copies `.config/` folder contents to `~/.config/`
  - Copies `.local/` folder contents and dedicated `.local/share/` to `~/.local/share/`
- **Wallpaper Management**:
  - Desktop wallpaper (light and dark modes) applied from `wallpaper.jpg`.
  - GDM Login screen wallpaper applied from `login-wallpaper.png` (via GDM dconf database update).
- **Import dconf Settings**: Automatically loads exported user preferences from `dconf-settings.ini` directly in the current user context (without `sudo`).
- **GNOME Extensions Management**: Downloads and activates selected extensions via `gnome-extensions-cli` (`gext`):
  - *Blur my Shell* (`blur-my-shell@aunetx`)
  - *Clipboard History* (`clipboard-history@alexsaveau.dev`)
  - *Compiz-alike Magic Lamp Effect* (`compiz-alike-magic-lamp-effect@hermes83.github.com`)
  - *Compiz Windows Effect* (`compiz-windows-effect@hermes83.github.com`)
  - *Dash to Dock* (`dash-to-dock@micxgx.gmail.com`)
  - *NetSpeed Indicator* (`netspeedindicator@subashghimire.info.np`)
  - *Weather Panel* (`weatherpanel@attentivecoder`)
- **User Avatar Setup**: Automatically sets user profile picture in AccountsService using `piwo.png`.

---

## 🐧 Supported Distributions

The script identifies the OS using `/etc/os-release` and selects the corresponding package manager:

| Distribution | Package Manager | Installed Packages |
| :--- | :--- | :--- |
| **Debian / Ubuntu / Pop!_OS / Mint** | `apt` | `gnome-tweaks`, `gnome-shell-extension-prefs`, `gnome-shell-extensions` |
| **Fedora** | `dnf` | `gnome-tweaks`, `gnome-extensions-app` |
| **Arch Linux / Manjaro** | `pacman` | `gnome-tweaks`, `gnome-shell-extensions` |
| **openSUSE** | `zypper` | `gnome-tweaks`, `gnome-shell-extensions` |

---

---

## 🛠 Prerequisites

1. **`sudo` Privileges**: Run the script as a **regular user** with `sudo` access (do not run directly as `root`).
2. **Pipx (Optional)**: Required for automatic GNOME extension installation via `gnome-extensions-cli`. If missing, extension installation will be skipped with a warning.

---

## 📥 Usage Instructions

1. **Clone or download** the repository containing your configuration files.
   ```bash
   git clone https://github.com/bartko4321/gnome-config.git
   ```
3. **Grant execution permissions**:
   ```bash
   chmod +x install.sh
   ```
4. **Execute the script**:
   ```bash
   ./install.sh
   ```

---

## 🔍 Module Details

### 1. Configuration Copy
Copies contents of `.local/share` into the user's home directory (`~/.local/share`), preserving directory structures and permissions.

### 2. Desktop & Login Wallpapers
- Desktop wallpaper is copied to `/home/$USER/Dokumenty/wallpaper.jpg` and applied via `gsettings`.
- GDM login background is copied to `/usr/share/backgrounds/custom/login-wallpaper.png`. The GDM dconf profile (`/etc/dconf/db/gdm.d/01-login-background`) is updated and recompiled with `sudo dconf update`.

### 3. Loading dconf Settings
The `dconf-settings.ini` file is sanitized for Windows CRLF line endings and loaded via:
```bash
dconf load / < dconf-settings.ini
```
This runs strictly under user permissions (without `sudo`), ensuring settings apply correctly to the user's dconf database.

### 4. User Avatar (AccountsService)
The image `piwo.png` is copied to `/var/lib/AccountsService/icons/$USER`, and `/var/lib/AccountsService/users/$USER` is updated with `Icon=...`.

---
[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/bartekszczecinski)

<img width="1280" height="800" alt="623801166-a24c0ed5-bc2b-4964-97e3-7559b32bdb53" src="https://github.com/user-attachments/assets/8d23e25e-ff72-4a83-833a-cd51d8538444" />


## ⚠️ Troubleshooting & Notes

- **Changes not visible after script completion?**
  Log out and log back in, or restart GNOME Shell (`Alt + F2`, type `r` and hit `Enter` on X11 sessions).
- **Extensions not activating automatically:**
  Some extensions require a GNOME Shell restart or re-login to be detected. You can also enable them manually via the *Extensions* app (`gnome-extensions-app`).
