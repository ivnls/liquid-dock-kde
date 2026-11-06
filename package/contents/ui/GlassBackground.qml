/*
 * Vidro líquido desenhado pelo próprio widget (usado no desktop, ou quando o
 * tema do painel não é o Liquid Glass). Camadas, de baixo para cima:
 *   1. tingimento translúcido claro/escuro conforme o esquema de cores;
 *   2. brilho especular vertical (mais forte no topo);
 *   3. aro interno difuso, que dá a sensação de espessura da lente;
 *   4. aro especular de 1,5 px em gradiente diagonal: luz no canto superior
 *      esquerdo e reflexo no inferior direito;
 *   5. filete escuro externo quase invisível, para definição em fundos claros.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Item {
    id: glass

    property real radius: Math.min(width, height) * 0.36
    property bool dark: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark

    // 1 + 2: corpo
    Rectangle {
        anchors.fill: parent
        radius: glass.radius
        color: glass.dark ? Qt.rgba(0.08, 0.08, 0.10, 0.30) : Qt.rgba(1, 1, 1, 0.22)
    }
    Rectangle {
        anchors.fill: parent
        radius: glass.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, glass.dark ? 0.12 : 0.22) }
            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.05) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, glass.dark ? 0.04 : 0.09) }
        }
    }

    // 3: aro interno difuso (anel de ~3 px)
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillRule: ShapePath.OddEvenFill
            strokeColor: "transparent"
            fillColor: Qt.rgba(1, 1, 1, glass.dark ? 0.06 : 0.10)
            PathRectangle { x: 1.5; y: 1.5; width: glass.width - 3; height: glass.height - 3; radius: glass.radius - 1.5 }
            PathRectangle { x: 4.5; y: 4.5; width: glass.width - 9; height: glass.height - 9; radius: glass.radius - 4.5 }
        }
    }

    // 4: aro especular em gradiente diagonal
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillRule: ShapePath.OddEvenFill
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: 0
                x2: glass.width; y2: glass.height
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.95) }
                GradientStop { position: 0.30; color: Qt.rgba(1, 1, 1, 0.35) }
                GradientStop { position: 0.60; color: Qt.rgba(1, 1, 1, 0.18) }
                GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0.70) }
            }
            PathRectangle { x: 0.25; y: 0.25; width: glass.width - 0.5; height: glass.height - 0.5; radius: glass.radius - 0.25 }
            PathRectangle { x: 1.75; y: 1.75; width: glass.width - 3.5; height: glass.height - 3.5; radius: glass.radius - 1.75 }
        }
    }

    // 5: filete externo
    Rectangle {
        anchors.fill: parent
        radius: glass.radius
        color: "transparent"
        border.width: 0.5
        border.color: Qt.rgba(0, 0, 0, glass.dark ? 0.35 : 0.10)
    }
}
