/*
 * Um app no Dock (fixado e/ou em execução), ligado ao TasksModel do Plasma.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.taskmanager as TaskManager

DockCell {
    id: task

    required property int index
    required property var model
    property var tasksModel

    readonly property bool isTask: true
    readonly property int itemIndex: index
    readonly property string launcherUrl: model.LauncherUrlWithoutIcon ? model.LauncherUrlWithoutIcon.toString() : ""
    readonly property bool hasWindows: model.IsWindow === true || model.IsGroupParent === true
    readonly property bool pinned: {
        tasksModel.launcherList; // dependência para reavaliar
        return launcherUrl !== "" && tasksModel.launcherPosition(launcherUrl) !== -1;
    }

    // Marca "abrindo" logo no clique, antes da notificação de inicialização chegar.
    property bool launching: false
    Timer { id: launchTimer; interval: 2200; onTriggered: task.launching = false }

    iconSource: model.decoration
    label: model.AppName || model.display || ""
    running: hasWindows
    bouncing: model.IsStartup === true || (launching && !hasWindows)
    attention: model.IsDemandingAttention === true
    dragEnabled: true

    // --- janelas do app ---------------------------------------------------------
    function modelIndex() {
        return tasksModel.makeModelIndex(index);
    }
    function windows() {
        if (model.IsGroupParent) {
            const out = [];
            for (let i = 0; i < model.ChildCount; ++i)
                out.push(tasksModel.makeModelIndex(index, i));
            return out;
        }
        return model.IsWindow ? [modelIndex()] : [];
    }
    function isWindowActive(idx) {
        return tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive) === true;
    }
    function launch() {
        launching = true;
        launchTimer.restart();
        tasksModel.requestNewInstance(modelIndex());
    }
    function bringAllToFront() {
        // Como no macOS: clicar traz todas as janelas do app para frente.
        const wins = windows();
        for (let i = wins.length - 1; i >= 0; --i)
            tasksModel.requestActivate(wins[i]);
    }
    function hideAll() {
        for (const w of windows()) {
            if (tasksModel.data(w, TaskManager.AbstractTasksModel.IsMinimized) !== true)
                tasksModel.requestToggleMinimized(w);
        }
    }
    function quit() {
        for (const w of windows())
            tasksModel.requestClose(w);
    }
    function togglePinned() {
        if (pinned)
            tasksModel.requestRemoveLauncher(launcherUrl);
        else
            tasksModel.requestAddLauncher(launcherUrl);
    }

    onClicked: m => {
        if (model.IsStartup)
            return;
        if (m.button === Qt.MiddleButton) {
            launch();
            return;
        }
        if (m.button === Qt.RightButton) {
            openMenu();
            return;
        }
        if (!hasWindows) {
            launch();
            return;
        }
        if (model.IsActive) {
            switch (Plasmoid.configuration.activeClickAction) {
            case 1:
                hideAll();
                break;
            case 2: {
                const wins = windows();
                let cur = wins.findIndex(w => isWindowActive(w));
                tasksModel.requestActivate(wins[(cur + 1) % wins.length]);
                break;
            }
            default:
                break; // macOS: não faz nada
            }
            return;
        }
        bringAllToFront();
    }

    // --- arrastar para reordenar / remover ---------------------------------------------
    onDragMoved: scenePos => {
        const grid = task.parent;
        const p = grid.mapFromItem(null, scenePos.x, scenePos.y);
        const target = grid.childAt(p.x, p.y);
        if (target && target.isTask && target.itemIndex !== task.itemIndex)
            tasksModel.move(task.itemIndex, target.itemIndex);
    }
    onDragFinished: (scenePos, outside) => {
        // Arrastado para fora: deixa de ficar fixado (se estiver aberto, continua no Dock até fechar).
        if (outside && pinned)
            tasksModel.requestRemoveLauncher(launcherUrl);
        tasksModel.syncLaunchers();
    }

    // --- menu de contexto ------------------------------------------------------
    function openMenu() {
        const menu = menuComponent.createObject(task);
        menu.build();
        menu.openRelative();
    }

    Component {
        id: menuItemComponent
        PlasmaExtras.MenuItem {}
    }

    Component {
        id: menuComponent

        PlasmaExtras.Menu {
            id: menu
            visualParent: task
            placement: task.dock.menuPlacement
            onStatusChanged: {
                if (status === PlasmaExtras.Menu.Closed)
                    destroy();
            }

            function add(props, action) {
                const item = menuItemComponent.createObject(menu, props);
                if (action)
                    item.clicked.connect(action);
                addMenuItem(item);
                return item;
            }

            function build() {
                const wins = task.windows();

                // Lista de janelas (marca a ativa)
                for (const w of wins) {
                    const title = task.tasksModel.data(w, Qt.DisplayRole) || task.label;
                    add({ text: title, checkable: true, checked: task.isWindowActive(w) },
                        () => task.tasksModel.requestActivate(w));
                }
                if (wins.length > 0)
                    addSeparator();

                if (task.launcherUrl !== "")
                    add({ text: wins.length > 0 ? i18n("Nova Janela") : i18n("Abrir"), icon: "window-new" }, task.launch);

                if (wins.length > 0)
                    add({ text: i18n("Mostrar Todas as Janelas"), icon: "view-grid" }, () => {
                        task.bringAllToFront();
                        task.dock.invokeKWinShortcut("ExposeClass");
                    });

                addSeparator();
                if (task.launcherUrl !== "")
                    add({ text: i18n("Manter no Dock"), checkable: true, checked: task.pinned }, () => {
                        task.togglePinned();
                        task.tasksModel.syncLaunchers();
                    });

                if (wins.length > 0) {
                    addSeparator();
                    add({ text: i18n("Ocultar"), icon: "window-minimize" }, task.hideAll);
                    add({ text: i18n("Encerrar"), icon: "application-exit" }, task.quit);
                }
            }
        }
    }
}
