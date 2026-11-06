#!/usr/bin/env python3
"""Gera os SVGs do tema Plasma "Liquid Glass".

O Plasma desenha painéis, diálogos e dicas de ferramenta a partir de
"FrameSvg": um SVG com 9 peças nomeadas (topleft, top, ..., center), que são
esticadas para o tamanho de cada janela. Este script desenha essas peças com a
linguagem visual do Liquid Glass:

  * corpo muito translúcido, tingido pela cor de fundo do esquema de cores
    (claro no modo claro, escuro no modo escuro), para o KWin desfocar atrás;
  * brilho especular branco mais forte no topo, decaindo para baixo;
  * aro de luz de 1,5 px: forte no canto superior esquerdo, reflexo no canto
    inferior direito (a luz "atravessa" o vidro), mais fraco embaixo à esquerda;
  * segundo aro interno, difuso, que simula a espessura/refração da lente;
  * filete escuro externo quase invisível, para dar definição sobre fundos claros;
  * cantos "contínuos" (curvatura suavizada, mais próxima de um squircle).

Uso:  python3 tools/gen-theme.py   (escreve em theme/liquid-glass/)
"""
from __future__ import annotations

import os
from dataclasses import dataclass

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "theme", "liquid-glass")

# Constante de controle das Béziers dos cantos. 0.5523 = círculo perfeito;
# valores maiores aproximam o canto contínuo (squircle) da Apple.
K = 0.62
STRETCH = 8  # largura/altura nominal das peças esticáveis


@dataclass
class Look:
    tint: float          # opacidade do tingimento pela cor do esquema
    sheen_top: float     # brilho branco no topo
    sheen_mid: float     # brilho branco no meio
    sheen_bottom: float  # brilho branco na base (leve reflexo)
    rim_tl: float        # aro: canto superior esquerdo
    rim_tr: float        # aro: canto superior direito
    rim_bl: float        # aro: canto inferior esquerdo
    rim_br: float        # aro: canto inferior direito
    inner: float         # aro interno difuso (espessura do vidro)
    outline: float       # filete escuro externo


TRANSLUCENT = Look(0.30, 0.20, 0.07, 0.10, 0.90, 0.55, 0.30, 0.65, 0.10, 0.10)
OPAQUE = Look(0.96, 0.10, 0.03, 0.05, 0.70, 0.45, 0.25, 0.50, 0.06, 0.18)


def corner_path(cx: float, cy: float, r: float, quadrant: str, inset: float = 0.0, close: bool = True) -> str:
    """Caminho de um canto arredondado contínuo dentro de uma célula r x r.

    (cx, cy) é a origem da célula. quadrant ∈ {tl, tr, bl, br}.
    Com close=True o caminho é a área preenchida do canto; com close=False é
    apenas o arco (para traçar o aro) deslocado `inset` para dentro.
    """
    a = r - inset  # raio efetivo
    k = K * a
    if quadrant == "tl":
        # arco de (inset, r) até (r, inset); centro em (r, r)
        p0 = (cx + inset, cy + r)
        c1 = (cx + inset, cy + r - k)
        c2 = (cx + r - k, cy + inset)
        p1 = (cx + r, cy + inset)
        corner_fill = [(cx + r, cy + r)]
    elif quadrant == "tr":
        p0 = (cx, cy + inset)
        c1 = (cx + k, cy + inset)
        c2 = (cx + a, cy + r - k)
        p1 = (cx + a, cy + r)
        corner_fill = [(cx, cy + r)]
    elif quadrant == "bl":
        p0 = (cx + r, cy + a)
        c1 = (cx + r - k, cy + a)
        c2 = (cx + inset, cy + k)
        p1 = (cx + inset, cy)
        corner_fill = [(cx + r, cy)]
    else:  # br
        p0 = (cx + a, cy)
        c1 = (cx + a, cy + k)
        c2 = (cx + k, cy + a)
        p1 = (cx, cy + a)
        corner_fill = [(cx, cy)]
    f = lambda p: f"{p[0]:.3f},{p[1]:.3f}"
    d = f"M{f(p0)} C{f(c1)} {f(c2)} {f(p1)}"
    if close:
        d += "".join(f" L{f(p)}" for p in corner_fill) + " Z"
    return d


class Frame:
    """Constrói as 9 peças (+ máscara + dicas) de um FrameSvg."""

    def __init__(self, r: int, margins: tuple[int, int, int, int], look: Look):
        self.r = r
        self.margins = margins  # top, bottom, left, right
        self.look = look
        self.defs: list[str] = []
        self.body: list[str] = []
        self._gid = 0

    # ---- utilidades -------------------------------------------------------
    def grad(self, stops: list[tuple[float, str, float]], vertical: bool = True) -> str:
        self._gid += 1
        gid = f"g{self._gid}"
        x2, y2 = ("0", "1") if vertical else ("1", "0")
        s = "".join(
            f'<stop offset="{o:.3f}" stop-color="{c}" stop-opacity="{a:.3f}"/>' for o, c, a in stops
        )
        self.defs.append(
            f'<linearGradient id="{gid}" x1="0" y1="0" x2="{x2}" y2="{y2}" '
            f'gradientUnits="objectBoundingBox">{s}</linearGradient>'
        )
        return f"url(#{gid})"

    @staticmethod
    def bounds(x, y, w, h) -> str:
        # Retângulo invisível que fixa a caixa delimitadora exata da peça.
        return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#000000" fill-opacity="0"/>'

    # ---- peças --------------------------------------------------------------
    def build(self, ox: int, oy: int, prefix: str = "") -> None:
        r, s, L = self.r, STRETCH, self.look
        mask = prefix == "mask-"
        top = (L.sheen_top, L.sheen_mid)
        sheen_corner_top = self.grad([(0, "#ffffff", top[0]), (1, "#ffffff", top[1] * 1.15)])
        sheen_mid = self.grad([(0, "#ffffff", top[1] * 1.15), (1, "#ffffff", L.sheen_mid)])
        sheen_bottom = self.grad([(0, "#ffffff", L.sheen_mid), (1, "#ffffff", L.sheen_bottom)])

        cells = {
            "topleft": (ox, oy, r, r, "tl"),
            "top": (ox + r, oy, s, r, None),
            "topright": (ox + r + s, oy, r, r, "tr"),
            "left": (ox, oy + r, r, s, None),
            "center": (ox + r, oy + r, s, s, None),
            "right": (ox + r + s, oy + r, r, s, None),
            "bottomleft": (ox, oy + r + s, r, r, "bl"),
            "bottom": (ox + r, oy + r + s, s, r, None),
            "bottomright": (ox + r + s, oy + r + s, r, r, "br"),
        }
        for name, (x, y, w, h, q) in cells.items():
            parts = [self.bounds(x, y, w, h)]
            shape = (
                f'<path d="{corner_path(x, y, r, q)}"' if q else f'<rect x="{x}" y="{y}" width="{w}" height="{h}"'
            )
            if mask:
                parts.append(shape + ' fill="#000000"/>')
                self.body.append(f'<g id="{prefix}{name}">{"".join(parts)}</g>')
                continue

            # 1) tingimento pela cor de fundo do esquema (claro/escuro)
            parts.append(
                shape + f' class="ColorScheme-Background" fill="currentColor" fill-opacity="{L.tint:.3f}"/>'
            )
            # 2) brilho especular vertical
            if name.startswith("top"):
                sheen = sheen_corner_top
            elif name.startswith("bottom"):
                sheen = sheen_bottom
            else:
                sheen = sheen_mid
            parts.append(shape + f' fill="{sheen}"/>')
            # 3) aros (externo escuro, especular, interno difuso)
            parts.extend(self.rims(name, x, y, w, h, q))
            self.body.append(f'<g id="{prefix}{name}">{"".join(parts)}</g>')

    def rims(self, name, x, y, w, h, q) -> list[str]:
        r, L = self.r, self.look
        out: list[str] = []
        corner_alpha = {"tl": L.rim_tl, "tr": L.rim_tr, "bl": L.rim_bl, "br": L.rim_br}
        if q:
            out.append(
                f'<path d="{corner_path(x, y, r, q, 0.25, close=False)}" fill="none" '
                f'stroke="#000000" stroke-opacity="{L.outline:.3f}" stroke-width="0.5"/>'
            )
            out.append(
                f'<path d="{corner_path(x, y, r, q, 1.0, close=False)}" fill="none" '
                f'stroke="#ffffff" stroke-opacity="{corner_alpha[q]:.3f}" stroke-width="1.5"/>'
            )
            out.append(
                f'<path d="{corner_path(x, y, r, q, 3.0, close=False)}" fill="none" '
                f'stroke="#ffffff" stroke-opacity="{L.inner:.3f}" stroke-width="2.5"/>'
            )
            return out

        # bordas retas: (posição da linha ao longo da espessura, gradiente ao longo do comprimento)
        if name == "center":
            return out
        horizontal = name in ("top", "bottom")
        a0, a1 = {
            "top": (L.rim_tl, L.rim_tr),
            "bottom": (L.rim_bl, L.rim_br),
            "left": (L.rim_tl, L.rim_bl),
            "right": (L.rim_tr, L.rim_br),
        }[name]
        g = self.grad([(0, "#ffffff", a0), (1, "#ffffff", a1)], vertical=not horizontal)

        def line(offset, thickness, fill, extra=""):
            # offset: distância da borda externa
            if name == "top":
                return f'<rect x="{x}" y="{y + offset}" width="{w}" height="{thickness}" fill="{fill}"{extra}/>'
            if name == "bottom":
                return f'<rect x="{x}" y="{y + h - offset - thickness}" width="{w}" height="{thickness}" fill="{fill}"{extra}/>'
            if name == "left":
                return f'<rect x="{x + offset}" y="{y}" width="{thickness}" height="{h}" fill="{fill}"{extra}/>'
            return f'<rect x="{x + w - offset - thickness}" y="{y}" width="{thickness}" height="{h}" fill="{fill}"{extra}/>'

        out.append(line(0.0, 0.5, "#000000", f' fill-opacity="{L.outline:.3f}"'))
        out.append(line(0.25, 1.5, g))
        out.append(line(1.75, 2.5, "#ffffff", f' fill-opacity="{L.inner:.3f}"'))
        return out

    def hints(self, ox: int, oy: int) -> None:
        t, b, l, rr = self.margins
        h = lambda name, w, hh, dx: self.body.append(
            f'<rect id="{name}" x="{ox + dx}" y="{oy}" width="{w}" height="{hh}" fill="#ff0000" fill-opacity="0"/>'
        )
        h("hint-top-margin", 4, t, 0)
        h("hint-bottom-margin", 4, b, 8)
        h("hint-left-margin", l, 4, 16)
        h("hint-right-margin", rr, 4, 40)
        h("hint-stretch-borders", 4, 4, 64)

    def svg(self) -> str:
        r, s = self.r, STRETCH
        size = 2 * r + s
        self.build(0, 0)
        self.build(size + 20, 0, "mask-")
        self.hints(0, size + 20)
        width = 2 * size + 40
        height = size + 40
        style = (
            '<style type="text/css" id="current-color-scheme">'
            ".ColorScheme-Background{color:#eff0f1;}"
            ".ColorScheme-Text{color:#232629;}"
            "</style>"
        )
        return (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}">\n'
            f"<defs>{style}{''.join(self.defs)}</defs>\n" + "\n".join(self.body) + "\n</svg>\n"
        )


# arquivo -> (raio do canto, margens topo/base/esq/dir)
FRAMES = {
    "widgets/panel-background.svg": (24, (6, 6, 8, 8)),
    "dialogs/background.svg": (16, (10, 10, 10, 10)),
    "widgets/tooltip.svg": (11, (5, 5, 10, 10)),
    "widgets/background.svg": (20, (12, 12, 12, 12)),
}


def main() -> None:
    for variant, look in (("", TRANSLUCENT), ("translucent/", TRANSLUCENT), ("opaque/", OPAQUE)):
        for rel, (r, margins) in FRAMES.items():
            path = os.path.join(ROOT, variant + rel)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(Frame(r, margins, look).svg())
            print("escrito", os.path.relpath(path, os.path.join(ROOT, "..", "..")))


if __name__ == "__main__":
    main()
