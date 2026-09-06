// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.ktabletop

Kirigami.Page {
    id: root

    title: "Lobby"

    required property LuaObject d
    actions: [
        Kirigami.Action {
            text: "Create Room"
            icon.name: "list-add"
            onTriggered: createRoomDialog.open()
        }
    ]

    QQC2.Label {
        anchors.centerIn: parent
        text: "No rooms yet, players = " + d.playerCount + " " + d.objectName
    }

    CreateRoomDialog {
        id: createRoomDialog
    }

    onBackRequested: event => {
        event.accepted = true;
        Kirigami.PageStack.pop();
        console.log("Quitting lobby!")
    }
}
