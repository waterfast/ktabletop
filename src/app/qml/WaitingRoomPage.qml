// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ktabletop

Kirigami.Page {
    id: root

    title: root.d.name !== "" ? root.d.name : i18n("Waiting Room")

    required property LuaObject d
    actions: [
        Kirigami.Action {
            text: i18n("Add Robot")
            icon.name: "computer-symbolic"
            visible: root.d.ownerId === root.d.selfId
            enabled: root.d.players.length < root.d.capacity
            onTriggered: root.d.invoke("addRobot")
        },
        Kirigami.Action {
            text: i18n("Start Game")
            icon.name: "media-playback-start"
            visible: root.d.ownerId === root.d.selfId
            enabled: root.d.players.length === root.d.capacity
            onTriggered: root.d.invoke("startGame")
        },
        Kirigami.Action {
            text: i18n("Chat")
            icon.name: "dialog-messages"
            checkable: true
            checked: chatDrawer.opened
            onTriggered: {
                if (chatDrawer.opened) {
                    chatDrawer.close();
                } else {
                    chatDrawer.open();
                }
            }
        },
        Kirigami.Action {
            text: i18n("Quit Room")
            icon.name: "application-exit"
            onTriggered: root.d.invoke("quitRoom")
        }
    ]

    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                Layout.alignment: Qt.AlignHCenter
                level: 3
                text: i18n("Waiting players")
            }

            QQC2.Label {
                Layout.alignment: Qt.AlignHCenter
                text: i18n("%1 / %2 players", root.d.players.length, root.d.capacity)
                opacity: 0.7
            }

            QQC2.ProgressBar {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                Layout.alignment: Qt.AlignHCenter
                from: 0
                to: root.d.capacity
                value: root.d.players.length
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: root.d.players
                delegate: Kirigami.AbstractCard {
                    id: playerCard
                    required property var modelData

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.mediumSpacing

                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            source: playerCard.modelData.id === root.d.ownerId ? "im-user-star" : "im-user"
                        }

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: playerCard.modelData.username
                            font.bold: playerCard.modelData.id === root.d.ownerId
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Badge {
                                visible: playerCard.modelData.id === root.d.selfId
                                text: i18n("You")
                            }

                            Kirigami.Badge {
                                visible: playerCard.modelData.id === root.d.ownerId
                                text: i18n("Owner")
                                customColor: Kirigami.Theme.positiveBackgroundColor
                                customTextColor: Kirigami.Theme.positiveTextColor
                            }
                        }
                    }
                }
            }
        }

        Repeater {
            model: Math.max(0, root.d.capacity - root.d.players.length)
            delegate: Kirigami.AbstractCard {
                Layout.fillWidth: true
                opacity: 0.5
                showClickFeedback: false

                contentItem: RowLayout {
                    spacing: Kirigami.Units.mediumSpacing
                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
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

    Kirigami.OverlayDrawer {
        id: chatDrawer
        edge: Qt.RightEdge
        parent: QQC2.Overlay.overlay
        width: Kirigami.Units.gridUnit * 18

        contentItem: ChatPanel {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            messages: root.d.messages
            selfId: root.d.selfId
            onSendRequested: text => root.d.invoke("sendChatMessage", [text])
        }
    }
}
