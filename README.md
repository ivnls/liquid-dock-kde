# Liquid Glass Dock para KDE Plasma 6

Um Dock no estilo do macOS com o visual Liquid Glass, feito como widget nativo do Plasma 6 (testado contra a API do Plasma 6.x, alvo 6.8.2).

Ele tem duas partes:

| Parte | O que faz |
|---|---|
| **Widget** `com.github.liquidglass.dock` (`package/`) | Apps fixados e abertos (via `TasksModel` do Plasma), pontos de "aberto", nome flutuante, animação de quique, ampliação, botão Aplicativos, divisória e Lixeira. |
| **Tema de Plasma** `liquid-glass` (`theme/`) | Fundo de vidro do painel, menus e dicas: corpo translúcido tingido pelo esquema de cores (claro/escuro), brilho especular no topo, aro de luz com reflexo no canto inferior direito, aro interno de "espessura" e cantos contínuos. O KWin desfoca e satura o que fica atrás (`plasmarc` → `ContrastEffect`). |

## Instalação

```bash
git clone <este repositório> && cd liquid-glass-dock
./install.sh
```

O instalador:
1. instala ou atualiza o widget e o tema com `kpackagetool6`;
2. pergunta se deve aplicar o tema (`plasma-apply-desktoptheme liquid-glass`);
3. pergunta se deve criar o painel do Dock: flutuante, centralizado, **largura ajustada ao conteúdo**, translúcido, com "desviar das janelas".

Opções úteis: `-y` (sim para tudo), `--thickness 76`, `--hiding autohide`, `--move-bottom-panel` (move o painel inferior atual para o topo, como a barra de menus do macOS).

**Manualmente:** botão direito na área de trabalho → *Adicionar painel → Painel vazio* → *Adicionar widgets → Liquid Glass Dock*. Nas configurações do painel, escolha *Flutuante*, *Centralizado*, largura *Ajustar ao conteúdo* e opacidade *Translúcido*.

Para remover: `./uninstall.sh`.

## Comportamento (igual ao macOS)

- **Clique**: abre o app, ou traz todas as janelas dele para frente. Clicar no app que já está em uso não faz nada (dá para mudar para *minimizar* ou *alternar janelas*).
- **Clique do meio**: nova janela.
- **Botão direito**: lista de janelas, Nova Janela, Mostrar Todas as Janelas (Exposé do app), Manter no Dock, Ocultar, Encerrar.
- **Arrastar um ícone**: reordena. Arrastar para longe do Dock e soltar tira o app do Dock.
- **Soltar um `.desktop`** (do menu de aplicativos ou do Dolphin) no Dock: fixa o app.
- **Lixeira**: ícone muda quando há itens. Soltar arquivos nela move-os para a lixeira. Botão direito → Esvaziar (pede confirmação).
- **Aplicativos**: abre o menu de aplicativos do Plasma (ou Visão geral, Grade, KRunner).

## Configurações

Botão direito no Dock → *Configurar Liquid Glass Dock…*: tamanho dos ícones (automático pela altura do painel), espaçamento, ampliação, blocos de vidro uniformes atrás dos ícones, indicadores, nomes, animações, botão Aplicativos, Lixeira e modo de vidro:

- **Automático**: no painel usa o tema Liquid Glass (com desfoque do KWin); fora do painel (na área de trabalho) o widget desenha o próprio vidro.
- **Vidro próprio do widget**: use se não quiser trocar o tema global. Nesse modo o widget não ganha desfoque do KWin, porque um widget não pode pedir desfoque para a própria área.

## Limitações conhecidas

- **Ampliação**: um widget é desenhado dentro da janela do painel, então o ícone ampliado não pode passar dela. A ampliação vai só até o espaço livre (margens do tema + vão do painel flutuante), bem menos que no macOS. Por isso ela vem desligada, que também é o padrão do macOS.
- **Refração real**: o Liquid Glass da Apple distorce o conteúdo atrás das bordas. O KWin oferece desfoque e saturação, mas não lente. Aqui a refração é simulada com os aros de luz.
- Ações rápidas do app (jump lists do `.desktop`) e a seção de "apps recentes" ainda não estão no menu.

## Desenvolvimento

- O tema é gerado por `tools/gen-theme.py`. Edite as constantes `TRANSLUCENT`/`OPAQUE` e rode o script de novo.
- Para testar o widget numa janela: `plasmawindowed com.github.liquidglass.dock`. Para testar num painel, depois de `./install.sh`, rode `systemctl --user restart plasma-plasmashell`.
- Logs: `journalctl --user -f -u plasma-plasmashell`.

Licença: GPL-3.0-or-later.
