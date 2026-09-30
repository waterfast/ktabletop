// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: root

    property var gameOverResult

    signal backToRoom()
    signal backToLobby()

    readonly property string resultKind: root.gameOverResult && root.gameOverResult.result ? root.gameOverResult.result : "draw"
    readonly property var winners: root.gameOverResult && root.gameOverResult.winners ? root.gameOverResult.winners : []

    title: {
        if (root.resultKind === "win") {
            return i18n("You win!");
        }
        if (root.resultKind === "lose") {
            return i18n("You lose!");
        }
        return i18n("Draw!");
    }
    modal: true
    closePolicy: QQC2.Popup.NoAutoClose
    standardButtons: Kirigami.Dialog.NoButton
    padding: Kirigami.Units.largeSpacing

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.iconSizes.huge
            implicitHeight: Kirigami.Units.iconSizes.huge
            source: {
                if (root.resultKind === "win") {
                    return "flag";
                }
                if (root.resultKind === "lose") {
                    return "dialog-error";
                }
                return "dialog-information";
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            visible: root.winners.length > 0
            text: i18n("Winner: %1", root.winners.join(", "))
        }
    }

    customFooterActions: [
        Kirigami.Action {
            text: i18n("Back to Room")
            icon.name: "go-home"
            onTriggered: root.backToRoom()
        },
        Kirigami.Action {
            text: i18n("Back to Lobby")
            icon.name: "go-previous"
            onTriggered: root.backToLobby()
        }
    ]
}
