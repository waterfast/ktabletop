// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ktabletop

Kirigami.Page {
    id: root

    title: d.name !== "" ? d.name : i18n("Waiting Room")

    required property LuaObject d
    actions: [
        Kirigami.Action {
            text: i18n("Add Robot")
            icon.name: "computer-symbolic"
            visible: d.ownerId === d.selfId
            enabled: d.players.length < d.capacity
            onTriggered: d.invoke("addRobot")
        },
        Kirigami.Action {
            text: i18n("Start Game")
            icon.name: "media-playback-start"
            visible: d.ownerId === d.selfId
            enabled: d.players.length === d.capacity
            onTriggered: d.invoke("startGame")
        },
        Kirigami.Action {
            text: i18n("Quit Room")
            icon.name: "application-exit"
            onTriggered: d.invoke("quitRoom")
        }
    ]

    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            Layout.alignment: Qt.AlignHCenter
            level: 3
            text: i18n("%1 / %2 players", d.players.length, d.capacity)
        }

        Repeater {
            model: d.players
            delegate: Kirigami.AbstractCard
            {
                required property var modelData
                Layout.fillWidth: true

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: modelData.id === d.ownerId ? "im-user-star" : "im-user"
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: modelData.username + (modelData.id === d.selfId ? i18n(" (you)") : "")
                        font.bold: modelData.id === d.ownerId
                    }

                    QQC2.Label {
                        visible: modelData.id === d.ownerId
                        text: i18n("Host")
                        opacity: 0.6
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }

        Repeater {
            model: Math.max(0, d.capacity - d.players.length)
            delegate: Kirigami.AbstractCard {
                Layout.fillWidth: true
                opacity: 0.5

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: "im-invisible-user"
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: i18n("Waiting for a player...")
                    }
                }
            }
        }
    }
}
