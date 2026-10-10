// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick

import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: root

    required property LuaObject d
    required property I18nContext i18nContext

    readonly property var players: root.d ? (root.d.players ?? []) : []
    readonly property var gameOver: root.d ? (root.d.gameOver ?? null) : null

    title: root.d ? (root.d.title ?? root.d.name ?? "") : ""

    actions: [
        Kirigami.Action {
            text: i18n("Back to Room")
            icon.name: "go-home"
            visible: root.gameOver !== null && root.gameOver !== undefined
            onTriggered: root.d.invoke("leaveToRoom")
        },
        Kirigami.Action {
            text: i18n("Quit Room")
            icon.name: "application-exit"
            onTriggered: root.d.invoke("leaveToLobby")
        }
    ]

    Loader {
        id: gameOverLoader
        active: root.gameOver !== null && root.gameOver !== undefined
        sourceComponent: GameOverDialog {
            gameOverResult: root.gameOver
            onBackToRoom: root.d.invoke("leaveToRoom")
            onBackToLobby: root.d.invoke("leaveToLobby")
        }
        onLoaded: item.open()
    }
}
