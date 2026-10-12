// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami

import org.kde.ktabletop

Kirigami.Page {
    id: root

    title: i18n("Plugin Manager")

    actions: [
        Kirigami.Action {
            text: i18n("Install New")
            icon.name: "get-hot-new-stuff"
            onTriggered: installDialog.open()
        },
        Kirigami.Action {
            text: i18n("Back")
            icon.name: "go-previous"
            onTriggered: Backend.mainViewModel.packManagerVisible = false
        }
    ]

    Kirigami.Dialog {
        id: installDialog
        title: i18n("Install Plugin")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        padding: Kirigami.Units.largeSpacing
        onAccepted: Backend.mainViewModel.installPack(repoUrlField.text.trim())
        onClosed: repoUrlField.text = ""

        contentItem: Kirigami.FormLayout {
            QQC2.TextField {
                id: repoUrlField
                Kirigami.FormData.label: i18n("Repository URL:")
            }
        }
    }
}
