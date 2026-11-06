#!/usr/bin/env bash
# Instala o Liquid Glass Dock (widget + tema de Plasma) para o usuário atual.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIDGET_ID="com.github.liquidglass.dock"
THEME_ID="liquid-glass"

APPLY_THEME=ask
CREATE_PANEL=ask
MOVE_BOTTOM=false
THICKNESS=68
HIDING=dodgewindows

usage() {
  cat <<USAGE
Uso: ./install.sh [opções]

  --apply-theme / --no-apply-theme   aplica (ou não) o tema de Plasma "Liquid Glass"
  --panel / --no-panel               cria (ou não) o painel do Dock na borda inferior
  --move-bottom-panel                se já houver painel embaixo, move-o para o topo
  --thickness N                      altura do Dock em px (padrão: 68)
  --hiding MODO                      none | autohide | dodgewindows | windowsgobelow (padrão: dodgewindows)
  -y, --yes                          responde "sim" a tudo
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply-theme) APPLY_THEME=yes ;;
    --no-apply-theme) APPLY_THEME=no ;;
    --panel) CREATE_PANEL=yes ;;
    --no-panel) CREATE_PANEL=no ;;
    --move-bottom-panel) MOVE_BOTTOM=true ;;
    --thickness) THICKNESS="$2"; shift ;;
    --hiding) HIDING="$2"; shift ;;
    -y|--yes) APPLY_THEME=yes; CREATE_PANEL=yes ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

[[ "$THICKNESS" =~ ^[0-9]+$ ]] || { echo "--thickness precisa ser um número" >&2; exit 1; }
case "$HIDING" in none|autohide|dodgewindows|windowsgobelow|windowscover|windowsbelow) ;; *)
  echo "--hiding inválido: $HIDING" >&2; exit 1 ;; esac

ask() { # ask VAR "pergunta"
  local -n ref="$1"
  if [[ "$ref" == ask ]]; then
    read -r -p "$2 [s/N] " reply || reply=""
    [[ "$reply" =~ ^[sSyY] ]] && ref=yes || ref=no
  fi
}

need() { command -v "$1" >/dev/null 2>&1 || { echo "Comando necessário não encontrado: $1" >&2; exit 1; }; }
need kpackagetool6

install_pkg() { # tipo id caminho
  if kpackagetool6 -t "$1" -s "$2" >/dev/null 2>&1; then
    echo "→ Atualizando $2"
    kpackagetool6 -t "$1" -u "$3"
  else
    echo "→ Instalando $2"
    kpackagetool6 -t "$1" -i "$3"
  fi
}

install_pkg Plasma/Applet "$WIDGET_ID" "$HERE/package"
install_pkg Plasma/Theme "$THEME_ID" "$HERE/theme/liquid-glass"

ask APPLY_THEME "Aplicar o tema de Plasma \"Liquid Glass\" (vidro em painéis, menus e dicas)?"
if [[ "$APPLY_THEME" == yes ]]; then
  need plasma-apply-desktoptheme
  plasma-apply-desktoptheme "$THEME_ID"
fi

ask CREATE_PANEL "Criar o painel do Dock na borda inferior agora?"
if [[ "$CREATE_PANEL" == yes ]]; then
  need dbus-send
  script="$(sed -e "s/__THICKNESS__/$THICKNESS/" -e "s/__HIDING__/$HIDING/" -e "s/__FORCE__/$MOVE_BOTTOM/" \
    "$HERE/scripts/create-dock-panel.js")"
  if ! out="$(dbus-send --session --print-reply --type=method_call --dest=org.kde.plasmashell \
      /PlasmaShell org.kde.PlasmaShell.evaluateScript "string:$script" 2>&1)"; then
    echo "Não foi possível criar o painel:" >&2
    echo "$out" | sed -n 's/.*Error: //p' >&2
    echo "Você pode adicioná-lo manualmente: botão direito na área de trabalho → Adicionar painel → Painel vazio," >&2
    echo "depois \"Adicionar widgets\" → Liquid Glass Dock." >&2
    exit 1
  fi
  echo "→ Painel criado."
fi

cat <<DONE

Pronto! Se você estava atualizando uma versão anterior, reinicie o Plasma para carregar o novo QML:

  systemctl --user restart plasma-plasmashell

Dica: em Configurações do Sistema → Gerenciamento de janelas → Efeitos da área de trabalho → Desfoque,
um desfoque forte (~10) com pouco ruído deixa o vidro mais próximo do macOS.
DONE
