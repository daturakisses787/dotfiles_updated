# dotfiles_updated – Projekt-Kontext

EndeavourOS + Hyprland Dotfiles mit modularem Installationssystem.

## Architektur

- **Orchestrator:** `install.sh` – Argument-Parsing, Modul-Discovery, Summary
- **Libraries:** `lib/common.sh` (Logging, link_config), `lib/checks.sh` (Pre-flight), `lib/idempotent.sh` (Zustandsprüfung)
- **Module:** `modules/00-20*.sh` – je eine `module_run()` Funktion, Metadata als Kommentare
- **Theme-System:** 7 Gruppen in `themes/`, Templates in `themes/templates/`, Generator in `scripts/generate-themes.sh`

## Konventionen

### Bash-Skripte
- Shebang: `#!/usr/bin/env bash` + `set -euo pipefail`
- Shellcheck-konform (keine Warnungen)
- Keine hartkodierten Pfade – `$HOME`, `$XDG_CONFIG_HOME`, `$DOTFILES_DIR`
- `DOTFILES_DIR` wird dynamisch vom Script-Standort abgeleitet

### Module
- Dateiformat: `modules/NN-name.sh` (numerisch sortiert)
- Metadata-Header: `# Description:`, `# Severity:`, `# Depends:`, `# Fix:`, `# Autorun:`
- Jedes Modul definiert `module_run()` als Einstiegspunkt
- Idempotenz: vor jeder Aktion prüfen ob bereits erledigt (`pkg_installed`, `link_is_correct`, etc.)

### Paketlisten
- Eine `.txt`-Datei pro Kategorie in `packages/`
- Kommentare mit `#`, leere Zeilen werden ignoriert
- AUR-Pakete separat in `aur.txt`

### Theme-System
- 7 Gruppen (4 dark + 3 light) – NICHT 10
- `groups.conf`: Format `name|type|accent_hex`
- Templates in `themes/templates/*.tpl` generieren Configs für 6 Anwendungen

### Git
- Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
- Feature-Branches, nie direkt auf `main`

## Wichtige Pfade

| Pfad | Zweck |
|------|-------|
| `install.sh` | Haupt-Installer |
| `verify.sh` | Post-Install-Verifikation |
| `lib/` | Shared Functions |
| `modules/` | 21 Installationsmodule |
| `packages/` | 11 Paketlisten |
| `config/` | Symlinked nach `~/.config/` |
| `scripts/` | Symlinked nach `~/.local/bin/` |
| `themes/` | 7 Farbgruppen + Templates |
| `systemd/` | User-Services + Scripts |
| `extras/` | Kopiert (nicht verlinkt): Chromium, Claude, VSCode |

## Logging-API (aus lib/common.sh)

- `log_ok "msg"` – Erfolg (grün ✓)
- `log_err "msg"` – Fehler (rot ✗)
- `log_warn "msg"` – Warnung (gelb ⚡)
- `log_info "msg"` – Info (blau →)
- `log_title "msg"` – Abschnittstitel (cyan ===)
- `run_cmd <cmd>` – Dry-Run-fähiger Command-Wrapper
