/*
 * Liquid Glass Dock — widget de Dock para KDE Plasma 6 no estilo macOS.
 *
 * Coloque-o sozinho num painel flutuante, centralizado, com largura
 * "Ajustar ao conteúdo" (o install.sh faz isso) e use o tema de Plasma
 * "Liquid Glass" para o vidro desfocado pelo KWin.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtCore
import Qt.labs.folderlistmodel
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    // ---- geometria ---------------------------------------------------------------
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal || vertical
    readonly property int configuredIcon: Plasmoid.configuration.iconSize

    // Espessura do Dock (altura num painel horizontal).
    readonly property int thickness: inPanel
        ? (vertical ? width : height)
        : Math.round((configuredIcon > 0 ? configuredIcon : 56) / 0.80)
    readonly property int iconSize: configuredIcon > 0
        ? Math.min(configuredIcon, thickness)
        : Math.round(thickness * 0.80)
    readonly property int cellLength: Math.round(iconSize * (1 + Plasmoid.configuration.spacing / 100))
    readonly property real iconLift: Math.max(0, (thickness - iconSize) / 2 - dotInset - 4) * 0.5
    readonly property real dotInset: Math.max(0, thickness * 0.015)

    // A janela do painel corta o que passar dela: a ampliação fica limitada ao
    // espaço livre (margens do tema + vão do painel flutuante).
    readonly property real maxMagnify: inPanel ? (thickness + Kirigami.Units.gridUnit * 0.9) / iconSize : 2.0

    readonly property bool drawGlass: Plasmoid.configuration.glassMode === 2
        || (Plasmoid.configuration.glassMode === 0 && !inPanel)
    readonly property real padAlong: drawGlass ? thickness * 0.16 : Math.round(thickness * 0.04)

    // Posição do mouse ao longo do Dock (para a ampliação).
    property real hoverAxis: -1e6
    readonly property bool hovering: hoverAxis > -1e5
    property int layoutRevision: 0
    property Item dockArea: null

    // Posição dos menus de contexto conforme a borda da tela.
    readonly property int menuPlacement: {
        switch (Plasmoid.location) {
        case PlasmaCore.Types.LeftEdge: return PlasmaExtras.Menu.RightPosedTopAlignedPopup;
        case PlasmaCore.Types.TopEdge: return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup;
        case PlasmaCore.Types.RightEdge: return PlasmaExtras.Menu.LeftPosedTopAlignedPopup;
        default: return PlasmaExtras.Menu.TopPosedLeftAlignedPopup;
        }
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.icon: "preferences-desktop-icons"
    toolTipMainText: ""

    // ---- utilidades de sistema --------------------------------------------------------------
    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }
    function exec(cmd) {
        executable.connectSource(cmd);
    }
    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }
    function invokeKWinShortcut(name) {
        exec("dbus-send --session --type=method_call --dest=org.kde.kglobalaccel /component/kwin "
             + "org.kde.kglobalaccel.Component.invokeShortcut string:" + shellQuote(name));
    }
    function openApps() {
        switch (Plasmoid.configuration.appsButtonAction) {
        case 1: invokeKWinShortcut("Overview"); break;
        case 2: invokeKWinShortcut("Grid View"); break;
        case 3: exec("dbus-send --session --type=method_call --dest=org.kde.krunner /App org.kde.krunner.App.display"); break;
        default:
            exec("dbus-send --session --type=method_call --dest=org.kde.plasmashell /PlasmaShell "
                 + "org.kde.PlasmaShell.activateLauncherMenu");
        }
    }

    // ---- modelo de tarefas --------------------------------------------------------------
    TaskManager.ActivityInfo { id: activityInfo }
    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }

    TaskManager.TasksModel {
        id: tasksModel

        sortMode: TaskManager.TasksModel.SortManual
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        groupingWindowTasksThreshold: -1
        separateLaunchers: false
        launchInPlace: true
        hideActivatedLaunchers: true

        // Como no macOS, o Dock mostra apps de todas as áreas de trabalho e telas.
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: true
        filterSkipTaskbar: true

        activity: activityInfo.currentActivity
        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry

        Component.onCompleted: launcherList = Plasmoid.configuration.launchers
        onLauncherListChanged: {
            if (JSON.stringify(Plasmoid.configuration.launchers) !== JSON.stringify(launcherList))
                Plasmoid.configuration.launchers = launcherList;
        }
    }
    Connections {
        target: Plasmoid.configuration
        function onLaunchersChanged() {
            if (JSON.stringify(Plasmoid.configuration.launchers) !== JSON.stringify(tasksModel.launcherList))
                tasksModel.launcherList = Plasmoid.configuration.launchers;
        }
    }

    // ---- Lixeira ------------------------------------------------------------------
    FolderListModel {
        id: trashFiles
        folder: StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.local/share/Trash/files"
        showHidden: true
        showDirs: true
        showDotAndDotDot: false
    }

    // ---- representação ------------------------------------------------------------------
    fullRepresentation: Item {
        id: dockArea

        readonly property real length: content.implicitLength + root.padAlong * 2

        Layout.minimumWidth: root.vertical ? -1 : length
        Layout.preferredWidth: root.vertical ? root.thickness : length
        Layout.maximumWidth: root.vertical ? Infinity : length
        Layout.minimumHeight: root.vertical ? length : -1
        Layout.preferredHeight: root.vertical ? length : root.thickness
        Layout.maximumHeight: root.vertical ? length : Infinity

        Behavior on Layout.preferredWidth { enabled: !root.vertical; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on Layout.preferredHeight { enabled: root.vertical; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Component.onCompleted: root.dockArea = dockArea

        GlassBackground {
            visible: root.drawGlass
            anchors.centerIn: parent
            width: root.vertical ? root.thickness : dockArea.width
            height: root.vertical ? dockArea.height : root.thickness
            radius: root.thickness * 0.36
        }

        HoverHandler {
            id: hover
            onPointChanged: {
                if (hovered)
                    root.hoverAxis = root.vertical ? point.position.y : point.position.x;
            }
            onHoveredChanged: if (!hovered) root.hoverAxis = -1e6
        }

        // Soltar um .desktop (do menu de aplicativos ou do Dolphin) fixa o app.
        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: drop => {
                for (const u of drop.urls) {
                    if (String(u).endsWith(".desktop"))
                        tasksModel.requestAddLauncher(u);
                }
                tasksModel.syncLaunchers();
            }
        }

        Grid {
            id: content
            anchors.centerIn: parent
            rows: root.vertical ? -1 : 1
            columns: root.vertical ? 1 : -1
            spacing: 0
            readonly property real implicitLength: root.vertical ? implicitHeight : implicitWidth
            onPositioningComplete: root.layoutRevision++

            DockCell {
                dock: root
                visible: Plasmoid.configuration.showAppsButton
                iconSource: "applications-all-symbolic"
                label: i18n("Aplicativos")
                onClicked: m => { if (m.button === Qt.LeftButton) root.openApps(); }
            }

            Grid {
                id: taskGrid
                rows: root.vertical ? -1 : 1
                columns: root.vertical ? 1 : -1
                spacing: 0
                onPositioningComplete: root.layoutRevision++

                move: Transition {
                    NumberAnimation { properties: "x,y"; duration: 260; easing.type: Easing.OutCubic }
                }
                add: Transition {
                    NumberAnimation { property: "scale"; from: 0.2; to: 1; duration: 260; easing.type: Easing.OutBack }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                }

                Repeater {
                    model: tasksModel
                    delegate: TaskDelegate {
                        dock: root
                        tasksModel: tasksModel
                    }
                }
            }

            // Divisória antes da Lixeira
            Item {
                visible: Plasmoid.configuration.showTrash
                width: root.vertical ? root.thickness : Math.round(root.cellLength * 0.32)
                height: root.vertical ? Math.round(root.cellLength * 0.32) : root.thickness
                Rectangle {
                    anchors.centerIn: parent
                    width: root.vertical ? root.iconSize * 0.62 : 1
                    height: root.vertical ? 1 : root.iconSize * 0.62
                    color: Kirigami.Theme.textColor
                    opacity: 0.22
                }
            }

            DockCell {
                id: trash
                dock: root
                visible: Plasmoid.configuration.showTrash
                iconSource: trashFiles.count > 0 ? "user-trash-full" : "user-trash"
                label: i18n("Lixeira")
                onClicked: m => {
                    if (m.button === Qt.LeftButton)
                        Qt.openUrlExternally("trash:/");
                    else if (m.button === Qt.RightButton)
                        trashMenu.openRelative();
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["text/uri-list"]
                    onEntered: drag => drag.accept(Qt.MoveAction)
                    onDropped: drop => {
                        const files = Array.from(drop.urls);
                        if (files.length === 0)
                            return;
                        root.exec("kioclient move " + files.map(u => root.shellQuote(u)).join(" ") + " trash:/");
                        drop.accept(Qt.MoveAction);
                    }
                }

                PlasmaExtras.Menu {
                    id: trashMenu
                    visualParent: trash
                    placement: root.menuPlacement
                    PlasmaExtras.MenuItem {
                        text: i18n("Abrir")
                        icon: "document-open-folder"
                        onClicked: Qt.openUrlExternally("trash:/")
                    }
                    PlasmaExtras.MenuItem {
                        text: i18n("Esvaziar Lixeira…")
                        icon: "trash-empty"
                        enabled: trashFiles.count > 0
                        onClicked: root.exec("kdialog --title " + root.shellQuote(i18n("Esvaziar Lixeira"))
                            + " --warningcontinuecancel " + root.shellQuote(i18n("Tem certeza de que deseja apagar permanentemente os itens da Lixeira? Esta ação não pode ser desfeita."))
                            + " && (ktrash6 --empty || ktrash --empty)")
                    }
                }
            }
        }
    }
}
