// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.ktabletop

Kirigami.Page {
    id: root

    title: "Waiting Room"

    required property LuaObject d
    actions: [
        Kirigami.Action {
            text: "Quit Room"
            icon.name: "application-exit"
            onTriggered: d.invoke("quitRoom")
        }
    ]

    QQC2.Label {
        anchors.centerIn: parent
        text: "Welcome to the room!<br>Players = " + JSON.stringify(root.d.players) +
            "<br>room owner.id = " + root.d.ownerId
        font.pixelSize: 18 // TODO: Does kirigami offer some constant?
    }
}
