// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ktabletop

Kirigami.ScrollablePage {
    id: root

    title: i18n("Lobby")

    required property LuaObject d
    actions: [
        Kirigami.Action {
            text: i18n("Create room")
            icon.name: "list-add"
            onTriggered: createRoomDialog.open()
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
            text: i18n("Exit lobby")
            icon.name: "application-exit"
            onTriggered: quitLobbyDialog.open()
        }
    ]

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            visible: root.d.rooms.length > 0

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                source: "system-users-symbolic"
                opacity: 0.7
            }

            QQC2.Label {
                text: i18n("%1 players online · %2 rooms", root.d.userCount, root.d.rooms.length)
                opacity: 0.7
                font: Kirigami.Theme.smallFont
            }

            Item { Layout.fillWidth: true }
        }

        Kirigami.CardsLayout {
            visible: root.d.rooms.length > 0
            Repeater {
                model: root.d.rooms
                delegate: Kirigami.Card {
                    id: roomCard
                    required property var modelData

                    readonly property bool isFull: modelData.userCount >= modelData.capacity
                    readonly property bool isMine: modelData.ownerId === root.d.selfId

                    Layout.maximumWidth: Kirigami.Units.gridUnit * 20

                    actions: [
                        Kirigami.Action {
                            text: roomCard.isFull ? i18n("Room full") : i18n("join")
                            icon.name: "list-add"
                            enabled: !roomCard.isFull
                            onTriggered: d.invoke("joinRoom", [roomCard.modelData.id])
                        }
                    ]

                    header: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Heading {
                            Layout.fillWidth: true
                            level: 2
                            text: roomCard.modelData.name
                            elide: Text.ElideRight
                        }

                        Kirigami.Badge {
                            visible: roomCard.isMine
                            text: i18n("Your room")
                        }

                        Kirigami.Badge {
                            visible: roomCard.isFull
                            text: i18n("Full")
                            Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
                        }
                    }

                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.Label {
                            text: i18n("Players: %1/%2", roomCard.modelData.userCount, roomCard.modelData.capacity)
                            opacity: 0.7
                        }

                        QQC2.ProgressBar {
                            Layout.fillWidth: true
                            from: 0
                            to: roomCard.modelData.capacity
                            value: roomCard.modelData.userCount
                        }
                    }
                }
            }
        }

        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.gridUnit * 3
            visible: root.d.rooms.length === 0
            icon.name: "list-add"
            text: i18n("There aren't room yet")
            explanation: i18n("Create a room to start playing with friends")

            helpfulAction: Kirigami.Action {
                text: i18n("Create room")
                icon.name: "list-add"
                onTriggered: createRoomDialog.open()
            }
        }
    }

    CreateRoomDialog {
        id: createRoomDialog

        d: LuaObject {
            opts: ({ type: "create-room" })
        }

        onAccepted: {
            root.d.invoke("createRoom", [{ name: d.name, capacity: d.capacity }]);
        }
    }

    Kirigami.PromptDialog {
        id: quitLobbyDialog

        title: i18n("Exit lobby")
        subtitle: i18n("Are you sure you want to disconnect from this server?")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel

        onAccepted: root.d.invoke("disconnectFromHost");
    }

    Connections {
        target: root.d

        function onSignalEmitted(name, data) {
            if (name === "chatMessage") {
                chatPanel.messages.insert(0, data)
            }
        }
    }

    Kirigami.OverlayDrawer {
        id: chatDrawer
        edge: Qt.RightEdge
        parent: QQC2.Overlay.overlay
        width: Kirigami.Units.gridUnit * 18

        contentItem: ChatPanel {
            id: chatPanel
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            selfId: root.d.selfId
            onSendRequested: text => d.invoke("sendChatMessage", [text])
        }
    }

    Component.onCompleted: {
        d.invoke("fetchRooms")
    }
}
