# Globale Einstellungen

- Sprache: Antworte auf Deutsch, Code-Kommentare auf Englisch
- Bei Unsicherheiten: Plan erstellen und nachfragen statt raten
- Nutze Subagenten fuer Recherche-Aufgaben die viel Kontext verbrauchen

## System-Umgebung

- OS: Arch Linux
- WM: Hyprland (Wayland)
- Shell: zsh
- Terminal: Kitty
- Paketmanager: pacman + yay (AUR)

## Code-Stil

- Einfache, lesbare Loesungen bevorzugen
- Keine unnuetigen Abstraktionen
- Fehlerbehandlung nur an Systemgrenzen (User-Input, APIs, I/O)
- Bei neuen Projekten: Tech-Stack vorschlagen und bestaetigen lassen, nicht abfragen

## Git

- Conventional Commits: feat:, fix:, docs:, refactor:, chore:
- Committe nach jedem abgeschlossenen Feature
- Immer in Feature-Branches arbeiten, nie direkt auf main

## Bash-Skripte

- Immer: #!/usr/bin/env bash + set -euo pipefail
- Shellcheck-konform, keine Warnungen
- XDG-Pfade verwenden: $XDG_CONFIG_HOME, $XDG_DATA_HOME, $XDG_STATE_HOME, $XDG_CACHE_HOME
- Keine hartkodierten Pfade – nutze $HOME und XDG-Variablen

## Python

- Python 3.11+, Type Hints verwenden
- uv als Paketmanager bevorzugen
- Linting: ruff

## TypeScript / JavaScript

- Paketmanager: npm (oder was das Projekt nutzt)
- Formatter/Linting: Biome oder ESLint je nach Projekt
- Funktionale Komponenten, Named Exports bevorzugen

## Sicherheit

- Keine Secrets committen (.env, API-Keys, Credentials)
- Bei sudo-Befehlen immer erst nachfragen
