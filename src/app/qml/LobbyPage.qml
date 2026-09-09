// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ktabletop

Kirigami.ScrollablePage {
    id: root

    title: "Lobby"

    required property LuaObject d
    actions: [
        Kirigami.Action {
            text: "Create Room"
            icon.name: "list-add"
            onTriggered: createRoomDialog.open()
        },
        Kirigami.Action {
            text: "Quit Lobby"
            icon.name: "application-exit"
            onTriggered: quitLobbyDialog.open()
        }
    ]

    ColumnLayout {
        Kirigami.CardsLayout {
            Repeater {
                model: root.d.rooms
                delegate: Kirigami.Card {
                    required property var modelData

                    Layout.maximumWidth: Kirigami.Units.gridUnit * 30

                    actions: [
                        Kirigami.Action {
                            text: "Join"
                            icon.name: "list-add"
                            onTriggered: root.d.invoke("joinRoom", [modelData.id])
                        }
                    ]
                    header: Kirigami.Heading {
                        level: 2
                        text: modelData.name
                    }
                    contentItem: QQC2.Label {
                        text: `Players: ${modelData.playerCount}/${modelData.capacity}`
                    }
                }
            }
        }

        QQC2.Label {
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignHCenter
            text: "No rooms yet (players = " + d.playerCount + ")"
            visible: d.rooms.length === 0
        }
    }

    CreateRoomDialog {
        id: createRoomDialog

        d: LuaObject {
            opts: ({ type: "create-room" })
        }
    }

    Kirigami.PromptDialog {
        id: quitLobbyDialog

        title: "Quit Lobby"
        subtitle: "Are you sure to logout this server?"
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel

        onAccepted: root.d.invoke("disconnectFromHost");
    }

    Component.onCompleted: {
        d.invoke("fetchRooms")
    }
}
