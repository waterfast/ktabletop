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
            text: i18n("Exit lobby")
            icon.name: "application-exit"
            onTriggered: quitLobbyDialog.open()
        }
    ]

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            visible: d.rooms.length > 0
            text: i18n("%1 player online", d.playerCount)
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }

        Kirigami.CardsLayout {
            visible: d.rooms.length > 0
            Repeater {
                model: d.rooms
                delegate: Kirigami.Card {
                    required property var modelData

                    Layout.maximumWidth: Kirigami.Units.gridUnit * 20

                    actions: [
                        Kirigami.Action {
                            text: i18n("join")
                            icon.name: "list-add"
                            enabled: modelData.playerCount < modelData.capacity
                            onTriggered: d.invoke("joinRoom", [modelData.id])
                        }
                    ]
                    header: Kirigami.Heading {
                        level: 2
                        text: modelData.name
                        elide: Text.ElideRight
                    }
                    contentItem: QQC2.Label {
                        text: i18n("Players: %1/%2", modelData.playerCount, modelData.capacity)
                        opacity: 0.7
                    }
                }
            }
        }

        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.gridUnit * 3
            visible: d.rooms.length === 0
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

        onAccepted: d.invoke("disconnectFromHost");
    }

    Component.onCompleted: {
        d.invoke("fetchRooms")
    }
}