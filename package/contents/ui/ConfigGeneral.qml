/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_iconSize: iconSize.value
    property alias cfg_spacing: spacing.value
    property alias cfg_magnification: magnification.value
    property alias cfg_showIndicators: showIndicators.checked
    property alias cfg_showLabels: showLabels.checked
    property alias cfg_bounce: bounce.checked
    property alias cfg_activeClickAction: activeClickAction.currentIndex
    property alias cfg_showAppsButton: showAppsButton.checked
    property alias cfg_appsButtonAction: appsButtonAction.currentIndex
    property alias cfg_showTrash: showTrash.checked
    property alias cfg_uniformTiles: uniformTiles.checked
    property alias cfg_glassMode: glassMode.currentIndex

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Aparência") }

        QQC2.ComboBox {
            id: glassMode
            Kirigami.FormData.label: i18n("Vidro:")
            model: [i18n("Automático"), i18n("Tema do painel (Liquid Glass)"), i18n("Vidro próprio do widget")]
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("No painel, o modo automático usa o tema de Plasma \"Liquid Glass\", que permite ao KWin desfocar o que está atrás do Dock.")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Tamanho dos ícones:")
            QQC2.SpinBox { id: iconSize; from: 0; to: 256 }
            QQC2.Label { text: iconSize.value === 0 ? i18n("automático") : i18n("px") }
        }
        QQC2.SpinBox {
            id: spacing
            Kirigami.FormData.label: i18n("Espaçamento (%):")
            from: 0; to: 60
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Ampliação:")
            QQC2.Slider { id: magnification; from: 0; to: 100; stepSize: 5 }
            QQC2.Label { text: magnification.value === 0 ? i18n("desligada") : magnification.value + "%" }
        }
        QQC2.CheckBox { id: uniformTiles; text: i18n("Ícones sobre blocos de vidro uniformes") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Comportamento") }

        QQC2.CheckBox { id: showIndicators; Kirigami.FormData.label: i18n("Mostrar:"); text: i18n("Indicadores de apps abertos") }
        QQC2.CheckBox { id: showLabels; text: i18n("Nome do app ao passar o mouse") }
        QQC2.CheckBox { id: bounce; text: i18n("Animar abertura de apps") }
        QQC2.CheckBox { id: showAppsButton; text: i18n("Botão Aplicativos") }
        QQC2.CheckBox { id: showTrash; text: i18n("Lixeira") }

        QQC2.ComboBox {
            id: appsButtonAction
            Kirigami.FormData.label: i18n("Botão Aplicativos abre:")
            enabled: showAppsButton.checked
            model: [i18n("Menu de aplicativos"), i18n("Visão geral"), i18n("Grade de janelas"), i18n("KRunner")]
        }
        QQC2.ComboBox {
            id: activeClickAction
            Kirigami.FormData.label: i18n("Clique no app em uso:")
            model: [i18n("Não faz nada (macOS)"), i18n("Minimiza"), i18n("Alterna entre janelas")]
        }
    }
}
