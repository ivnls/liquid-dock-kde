#!/usr/bin/env bash
# Remove o widget e o tema. Remova o painel do Dock antes (modo de edição → Remover painel).
set -euo pipefail
kpackagetool6 -t Plasma/Applet -r com.github.liquidglass.dock || true
if command -v plasma-apply-desktoptheme >/dev/null && kreadconfig6 --file plasmarc --group Theme --key name 2>/dev/null | grep -qx liquid-glass; then
  plasma-apply-desktoptheme default || true
fi
kpackagetool6 -t Plasma/Theme -r liquid-glass || true
echo "Removido. Reinicie o Plasma: systemctl --user restart plasma-plasmashell"
