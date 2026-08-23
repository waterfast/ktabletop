// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: root

    title: "Create Room"

    customFooterActions: [
        Kirigami.Action {
            text: "OK"
            icon.name: "dialog-ok"
            onTriggered: {
                console.log("Create room:", nameField.text, playerCount.value)
                root.close()
            }
        },
        Kirigami.Action {
            text: "Cancel"
            icon.name: "dialog-cancel"
            onTriggered: root.close()
        }
    ]

    contentItem: ColumnLayout {
        QQC2.TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "Room name"
        }

        RowLayout {
            Layout.fillWidth: true

            QQC2.Label {
                text: "Players:"
            }

            QQC2.SpinBox {
                id: playerCount
                Layout.fillWidth: true
                from: 2
                to: 8
                value: 2
            }
        }
    }
}
