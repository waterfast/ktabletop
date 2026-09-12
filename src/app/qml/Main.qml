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

    property var _dynamicPages: []

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
                    root.pageStack.items: [root.createLuaPage("org.kde.ktabletop", "LobbyPage", { objectName: Backend.mainViewModel.lobbyViewModelName })]
                }
            },

            State {
                name: "waitingRoom"
                when: Backend.mainViewModel.connected && !Backend.mainViewModel.gameStarted && Backend.mainViewModel.roomId !== 0

                PropertyChanges {
                    root.pageStack.items: [root.createLuaPage("org.kde.ktabletop", "WaitingRoomPage", { objectName: Backend.mainViewModel.roomViewModelName })]
                }
            },

            State {
                name: "inGame"
                when: Backend.mainViewModel.gameStarted

                PropertyChanges {
                    root.pageStack.items: [root.createLuaPageByUrl(Backend.mainViewModel.gamePageUrl, { objectName: Backend.mainViewModel.gameViewModelName })]
                }
            }
        ]
    }

    pageStack {
        // columnView.columnResizeMode: KL.ColumnView.SingleColumn
        globalToolBar {
            style: Kirigami.ApplicationHeaderStyle.ToolBar
            showNavigationButtons: pageStack.currentIndex > 0 || pageStack.layers.depth > 1 ? Kirigami.ApplicationHeaderStyle.ShowBackButton : 0
        }

        onPageRemoved: page => {
            const idx = root._dynamicPages.findIndex(e => e === page);
            if (idx !== -1) {
                root._dynamicPages.splice(idx, 1);
                page.destroy();
            }
        }
    }

    function createLuaPage(uri, pageName, opts) {
        const pageComponent = Qt.createComponent(uri, pageName);
        if (pageComponent.status == Component.Error) {
            console.warn(pageComponent.errorString());
        }
        const lobject = Qt.createComponent("org.kde.ktabletop", "LuaObject");
        const d = lobject.createObject(null, { opts });
        const page = pageComponent.createObject(root, { d });
        d.parent = page;
        _dynamicPages.push(page);
        return page;
    }

    function createLuaPageByUrl(url, opts) {
        const pageComponent = Qt.createComponent(url);
        if (pageComponent.status == Component.Error) {
            console.warn(pageComponent.errorString());
        }
        const lobject = Qt.createComponent("org.kde.ktabletop", "LuaObject");
        const d = lobject.createObject(null, { opts });
        const page = pageComponent.createObject(root, { d });
        d.parent = page;
        _dynamicPages.push(page);
        return page;
    }

    Component.onCompleted: {
    }
}
