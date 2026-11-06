/*
 * Uma posição do Dock: ícone, ponto de "app aberto", rótulo flutuante,
 * ampliação, quique e efeito de pressionar. Usada por apps, botão
 * Aplicativos e Lixeira.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmaCore.ToolTipArea {
    id: cell

    // --- API --------------------------------------------------------------
    property var iconSource
    property string label
    property bool running: false          // mostra o ponto
    property bool bouncing: false          // quica enquanto true (abertura)
    property bool attention: false         // quica com pausas (pedindo atenção)
    property bool dragEnabled: false
    property alias pressed: mouse.pressed
    property alias containsMouse: mouse.containsMouse
    readonly property bool dragging: mouse.dragActive

    signal clicked(var mouse)
    signal dragMoved(point scenePos)
    signal dragFinished(point scenePos, bool outside)

    // --- geometria (vem do main.qml) ---------------------------------------
    property var dock                       // o PlasmoidItem raiz (main.qml)
    readonly property bool vertical: dock.vertical
    readonly property int edge: Plasmoid.location

    width: vertical ? dock.thickness : dock.cellLength
    height: vertical ? dock.cellLength : dock.thickness

    mainText: label
    location: Plasmoid.location
    active: Plasmoid.configuration.showLabels && !dragging && !mouse.pressed
    interactive: false

    // --- ampliação ---------------------------------------------------------
    // Centro desta célula no eixo do Dock, em coordenadas do Dock.
    readonly property real axisCenter: {
        dock.layoutRevision; x; y; // reavalia quando o layout muda
        const p = cell.mapToItem(dock.dockArea, width / 2, height / 2);
        return vertical ? p.y : p.x;
    }
    readonly property real magnify: {
        const amount = Plasmoid.configuration.magnification / 100;
        if (amount <= 0 || dock.hoverAxis < -1e5)
            return 1;
        const d = Math.abs(axisCenter - dock.hoverAxis) / dock.cellLength;
        const reach = 2.6; // em ícones, como no macOS
        if (d >= reach)
            return 1;
        const f = Math.cos(d / reach * Math.PI / 2);
        return Math.min(1 + amount * f * f, dock.maxMagnify);
    }

    // Direção "para longe da borda" (para quicar e ampliar).
    readonly property point away: {
        switch (edge) {
        case PlasmaCore.Types.TopEdge: return Qt.point(0, 1);
        case PlasmaCore.Types.LeftEdge: return Qt.point(1, 0);
        case PlasmaCore.Types.RightEdge: return Qt.point(-1, 0);
        default: return Qt.point(0, -1);
        }
    }

    // --- quique -------------------------------------------------------------
    property real bounceOffset: 0
    readonly property real bounceHeight: dock.thickness * 0.24

    SequentialAnimation {
        id: bounceAnim
        running: Plasmoid.configuration.bounce && (cell.bouncing || cell.attention)
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { target: cell; property: "bounceOffset"; to: cell.bounceHeight; duration: 280; easing.type: Easing.OutQuad }
        NumberAnimation { target: cell; property: "bounceOffset"; to: 0; duration: 280; easing.type: Easing.InQuad }
        // Pequeno "assentamento" ao tocar o chão
        NumberAnimation { target: cell; property: "bounceOffset"; to: cell.bounceHeight * 0.12; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: cell; property: "bounceOffset"; to: 0; duration: 90; easing.type: Easing.InQuad }
        PauseAnimation { duration: cell.attention && !cell.bouncing ? 900 : 60 }
    }

    // --- ícone ----------------------------------------------------------------
    Item {
        id: iconBox
        width: dock.iconSize
        height: dock.iconSize
        anchors.centerIn: parent
        // desloca levemente para longe da borda, abrindo espaço para o ponto
        anchors.horizontalCenterOffset: cell.away.x * dock.iconLift
        anchors.verticalCenterOffset: cell.away.y * dock.iconLift

        transform: Translate {
            x: cell.away.x * cell.bounceOffset
            y: cell.away.y * cell.bounceOffset
        }
        scale: cell.magnify
        transformOrigin: {
            switch (cell.edge) {
            case PlasmaCore.Types.TopEdge: return Item.Top;
            case PlasmaCore.Types.LeftEdge: return Item.Left;
            case PlasmaCore.Types.RightEdge: return Item.Right;
            default: return Item.Bottom;
            }
        }
        Behavior on scale {
            enabled: !dock.hovering
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Bloco de vidro uniforme (opcional), à la ícones do macOS 26+.
        Loader {
            anchors.fill: parent
            active: Plasmoid.configuration.uniformTiles
            sourceComponent: GlassBackground { radius: width * 0.225 }
        }

        Kirigami.Icon {
            id: icon
            anchors.centerIn: parent
            width: Plasmoid.configuration.uniformTiles ? parent.width * 0.68 : parent.width
            height: width
            source: cell.iconSource
            roundToIconSize: false
            smooth: true
            // escurece ao pressionar, como no macOS
            layer.enabled: mouse.pressed || cell.dragging
            layer.effect: MultiEffect {
                brightness: -0.28
            }
        }
    }

    // --- ponto de app aberto ------------------------------------------------------
    Rectangle {
        visible: Plasmoid.configuration.showIndicators
        opacity: cell.running ? 0.85 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        width: Math.max(3, Math.round(dock.thickness * 0.065))
        height: width
        radius: width / 2
        color: Kirigami.Theme.textColor
        x: cell.away.x === 0 ? (cell.width - width) / 2
           : (cell.away.x > 0 ? dock.dotInset : cell.width - width - dock.dotInset)
        y: cell.away.y === 0 ? (cell.height - height) / 2
           : (cell.away.y < 0 ? cell.height - height - dock.dotInset : dock.dotInset)
    }

    // --- entrada ------------------------------------------------------------------
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        preventStealing: true

        property point pressPos
        property bool dragActive: false

        onPressed: m => {
            pressPos = Qt.point(m.x, m.y);
            dragActive = false;
        }
        onPositionChanged: m => {
            if (!pressed || !cell.dragEnabled || !(m.buttons & Qt.LeftButton))
                return;
            if (!dragActive && Math.hypot(m.x - pressPos.x, m.y - pressPos.y) > Qt.styleHints.startDragDistance)
                dragActive = true;
            if (dragActive)
                cell.dragMoved(mapToItem(null, m.x, m.y));
        }
        onReleased: m => {
            if (dragActive) {
                // Soltar bem longe do Dock = remover do Dock (como arrastar para fora no macOS).
                const outside = cell.vertical
                    ? Math.abs(m.x - cell.width / 2) > cell.width * 1.3
                    : Math.abs(m.y - cell.height / 2) > cell.height * 1.3;
                cell.dragFinished(mapToItem(null, m.x, m.y), outside);
                dragActive = false;
                return;
            }
            if (containsMouse)
                cell.clicked(m);
        }
        onCanceled: dragActive = false
    }
}
