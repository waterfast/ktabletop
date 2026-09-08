// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick

import org.kde.kirigami as Kirigami

import org.kde.ktabletop

Kirigami.ApplicationWindow {
    id: root

    readonly property WelcomePage welcomePage: WelcomePage {
        parent: states
    }

    property Item states: Item {
        id: states
        states: [
            State {
                name: "notConnected"
                when: !Backend.mainViewModel.connected
                PropertyChanges {
                    root.pageStack.items: [welcomePage]
                }
            },

            State {
                name: "lobby"
                when: Backend.mainViewModel.connected && !Backend.mainViewModel.gameStarted && Backend.mainViewModel.roomId === 0
                PropertyChanges {
                    root.pageStack.items: [createLobbyPage()]
                }
            },

            State {
                name: "waitingRoom"
                when: Backend.mainViewModel.connected && !Backend.mainViewModel.gameStarted && Backend.mainViewModel.roomId !== 0
            },

            State {
                name: "inGame"
                when: Backend.mainViewModel.gameStarted
            }
        ]
    }

    pageStack {
        // columnView.columnResizeMode: KL.ColumnView.SingleColumn
        globalToolBar {
            style: Kirigami.ApplicationHeaderStyle.ToolBar
            showNavigationButtons: pageStack.currentIndex > 0 || pageStack.layers.depth > 1 ? Kirigami.ApplicationHeaderStyle.ShowBackButton : 0
        }
    }


    function createLobbyPage(): LobbyPage {
        const pageComponent = Qt.createComponent("org.kde.ktabletop", "LobbyPage");
        const lobject = Qt.createComponent("org.kde.ktabletop", "LuaObject");
        const d = lobject.createObject(null, {
            opts: { type: "lobby" }
        });
        return pageComponent.createObject(states, { d }) as LobbyPage;
    }

    Component.onCompleted: {
    }
}
