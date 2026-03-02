# dotfiles_updated

Reproduzierbare EndeavourOS-Installation mit Hyprland, NVIDIA und PipeWire.

## Features

- **21 modulare Installationsmodule** – einzeln oder komplett ausführbar
- **Idempotent** – sicher mehrfach ausführbar, erkennt bereits erledigte Schritte
- **Dry-Run-Modus** – Vorschau aller Änderungen ohne Ausführung
- **7 Farbthemen** – automatisch generiertes Theme-System (4 dark + 3 light)
- **Kategorisierte Paketlisten** – 11 Kategorien, ~148 Pakete

## Voraussetzungen

- EndeavourOS oder Arch-basierte Distribution
- Internetverbindung
- Regulärer Benutzer mit `sudo`-Rechten (nicht als root ausführen)

## Schnellstart

```bash
git clone https://github.com/<user>/dotfiles_updated.git ~/dotfiles_updated
cd ~/dotfiles_updated
./install.sh
```

## Verwendung

```bash
# Interaktives Menü
./install.sh

# Vollinstallation (Dry-Run)
./install.sh --dry-run

# Einzelnes Modul ausführen
./install.sh --module=04-setup-shell

# Module überspringen
./install.sh --skip=setup-nvidia,setup-libvirt

# Alle Module auflisten
./install.sh --list

# Installation verifizieren
./verify.sh
```

## Struktur

```
dotfiles_updated/
├── install.sh          Orchestrator (Argument-Parsing, Modul-Discovery)
├── verify.sh           Post-Install-Verifikation
├── lib/                Shared Libraries (Logging, Idempotenz, Checks)
├── modules/            21 Installationsmodule (numerisch sortiert)
├── packages/           11 kategorisierte Paketlisten
├── config/             Configs → symlinked nach ~/.config/
├── scripts/            14 Helper-Scripts → symlinked nach ~/.local/bin/
├── themes/             7 Farbgruppen + Templates + Generator
├── systemd/            User-Services (Bluetooth A2DP)
├── extras/             Persönliche Daten (kopiert, nicht verlinkt)
└── wallpapers/         .gitkeep (Bilder manuell hinzufügen)
```

## Module

| Nr  | Modul                      | Severity | Beschreibung                                           |
|-----|---------------------------|----------|--------------------------------------------------------|
| 00  | system-update             | kritisch | System-Update (`pacman -Syu`)                          |
| 01  | install-yay               | kritisch | AUR-Helper (yay) installieren                          |
| 02  | install-packages          | kritisch | Pakete aus `packages/` installieren                    |
| 03  | link-configs              | kritisch | Konfigurationen nach `~/.config` verlinken             |
| 04  | setup-shell               | wichtig  | ZSH + Oh-My-Zsh + Powerlevel10k                       |
| 05  | setup-theming             | wichtig  | GTK/Qt/Cursor/Icons Theme-System                       |
| 06  | install-fonts             | wichtig  | Schriftarten + Font-Cache                              |
| 07  | setup-wallpapers          | optional | Wallpapers aus Git-Repo klonen + swww                  |
| 08  | setup-nvidia              | wichtig  | NVIDIA-Umgebungsvariablen + Treiber                    |
| 09  | setup-bluetooth           | wichtig  | Bluetooth-Dienst aktivieren                            |
| 10  | setup-sddm                | wichtig  | SDDM mit Custom Theme                                 |
| 11  | setup-grub-theme          | optional | LoboGrubTheme installieren                             |
| 12  | setup-systemd-services    | optional | Bluetooth A2DP User-Service                            |
| 13  | setup-default-apps        | optional | Standard-Anwendungen (mimeapps.list)                   |
| 14  | setup-chromium            | optional | Chromium Bookmarks importieren                         |
| 15  | setup-vscode              | optional | VSCode Extensions installieren                         |
| 16  | setup-claude-config       | optional | Claude Code Konfiguration                              |
| 17  | setup-github-ssh          | manuell  | GitHub SSH-Key (mit `--module=17-setup-github-ssh`)    |
| 18  | setup-obsidian            | manuell  | Obsidian (mit `--module=18-setup-obsidian`)            |
| 19  | setup-libvirt             | optional | Libvirt/QEMU Virtualisierung                           |
| 20  | optional-packages         | optional | Discord, Steam, OBS, GIMP, LibreOffice                 |

**Severity:**
- **kritisch** – Fehler bricht Installation ab
- **wichtig** – sollte funktionieren, Fehler wird geloggt
- **optional** – nice-to-have, Fehler wird toleriert
- **manuell** – nur mit `--module=` explizit ausführbar

## Paketlisten

| Datei             | Inhalt                                      |
|-------------------|---------------------------------------------|
| `core.txt`        | Hyprland, Wayland, Polkit, XDG-Portale      |
| `terminal.txt`    | kitty, zsh, zsh-Plugins                     |
| `desktop.txt`     | waybar, wofi, dunst, hyprlock, swww, gvfs-mtp |
| `theming.txt`     | qt5ct, qt6ct, kvantum, nwg-look             |
| `media.txt`       | PipeWire-Stack, imagemagick, VLC, GStreamer  |
| `system-tools.txt`| btop, ripgrep, fd, bat, eza, jq             |
| `network.txt`     | NetworkManager, bluez, blueman              |
| `fonts.txt`       | JetBrains Mono Nerd, Noto Fonts             |
| `nvidia.txt`      | nvidia-open, nvidia-utils, lib32-nvidia-utils|
| `aur.txt`         | bibata-cursor, candy-icons, p10k, claude-code, buzz |
| `optional.txt`    | discord, steam, obs, gimp, libreoffice, blender, inkscape |

## Theme-System

7 Farbgruppen, automatisch generiert aus Wallpaper-Farben:

| Gruppe          | Typ   | Akzentfarbe |
|-----------------|-------|-------------|
| blue-dark       | dark  | `#5961c0`   |
| lime-dark       | dark  | `#c9cf81`   |
| pale-blue-dark  | dark  | `#597ec0`   |
| red-dark        | dark  | `#c26356`   |
| green-light     | light | `#7dbe55`   |
| indigo-light    | light | `#766bc7`   |
| red-light       | light | `#be4741`   |

### Theme wechseln

```bash
# Interaktiv
~/.local/bin/theme-toggle.sh

# Direkt
~/.local/bin/theme-toggle.sh blue-dark
```

### Themes neu generieren

```bash
~/.local/bin/generate-themes.sh
```

Templates in `themes/templates/` generieren Konfigurationen für: Hyprland, kitty, waybar, wofi, dunst, fastfetch.

## Konfigurationen

Folgende Configs werden nach `~/.config/` verlinkt:

- **hypr/** – Hyprland + 6 Subconfigs + hypridle.conf + hyprlock.conf
- **waybar/** – Statusbar
- **kitty/** – Terminal
- **wofi/** – App-Launcher
- **dunst/** – Benachrichtigungen
- **fastfetch/** – System-Info
- **btop/** – Systemmonitor
- **rofi/** – Launcher (Alternative)
- **Thunar/** – Dateimanager
- **xfce4/** – Thunar-Dependencies
- **Kvantum/** – Qt-Theme-Engine
- **qt5ct/** – Qt5-Einstellungen
- **qt6ct/** – Qt6-Einstellungen
- **gtk-3.0/** – GTK3-Einstellungen
- **mimeapps.list** – Standard-Anwendungen
- **zsh/.zshenv** – ZSH-Umgebung (ZDOTDIR → `~/.config/zsh/`)

Scripts aus `scripts/` (14 Stück) werden nach `~/.local/bin/` verlinkt.

## Wallpapers

Wallpaper-Dateien sind zu groß für Git und werden in einem separaten Repository verwaltet.

### Automatisch (empfohlen)

`WALLPAPER_REPO` in `install.sh` setzen – Modul 07 klont die Bilder automatisch:

```bash
# In install.sh die Variable anpassen:
WALLPAPER_REPO="https://github.com/<user>/wallpapers.git"

# Oder als Umgebungsvariable:
WALLPAPER_REPO="https://github.com/<user>/wallpapers.git" ./install.sh
```

### Manuell

1. Wallpapers nach `wallpapers/` kopieren
2. Zuordnung in `themes/wallpaper-map.conf` prüfen/anpassen
3. `~/.local/bin/generate-themes.sh` ausführen

## Verifikation

```bash
# Automatische Prüfung
./verify.sh

# Shellcheck
shellcheck install.sh lib/*.sh modules/*.sh

# Idempotenz-Test: zweites Mal ausführen → alles "already done"
./install.sh
```

## Troubleshooting

**Module einzeln ausführen:**
```bash
./install.sh --module=<name>
```

**Log prüfen:**
```bash
cat install.log
```

**NVIDIA-Probleme:**
```bash
nvidia-smi                        # Treiber-Status
./install.sh --module=08-setup-nvidia  # Modul erneut ausführen
```

**Theme-System kaputt:**
```bash
./install.sh --module=05-setup-theming
~/.local/bin/generate-themes.sh
```
