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
                when: true
                PropertyChanges {
                    root.pageStack.items: [welcomePage]
                }
            },

            State {
                name: "lobby"
                PropertyChanges {
                    root.pageStack.items: [createLobbyPage()]
                }
            },

            State {
                name: "waitingRoom"
            },

            State {
                name: "inGame"
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
        return pageComponent.createObject(states, {
            d: lobject.createObject(states, {
                opts: { type: "lobby" }
            } as LuaObject)
        }) as LobbyPage;
    }

    Component.onCompleted: {
    }
}
