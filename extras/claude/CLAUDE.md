# Globale Einstellungen

- Sprache: Antworte auf Deutsch, Code-Kommentare auf Englisch
- Erstelle bei Unsicherheiten einen Plan und frage nach statt zu raten
- Committe nach jedem abgeschlossenen Feature mit aussagekräftiger Message
- Nutze Subagenten für Recherche-Aufgaben die viel Kontext verbrauchen

## Bash-Skripte
- Immer: #!/usr/bin/env bash + set -euo pipefail
- Shellcheck-konform, keine Warnungen
- Keine hartkodierten Pfade – nutze $HOME, $XDG_CONFIG_HOME

## Git
- Conventional Commits: feat:, fix:, docs:, refactor:, chore:
- Immer in Feature-Branches arbeiten, nie direkt auf main
