// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick

import org.kde.kirigami as Kirigami

import org.kde.ktabletop

Kirigami.ApplicationWindow {
    id: root

    minimumWidth: 300
    minimumHeight: minimumWidth + 1

    readonly property WelcomePage welcomePage: WelcomePage {
        parent: states
    }

    property var _dynamicPages: []

    readonly property bool isWidescreen: width >= Kirigami.Units.gridUnit * 30 // = 480
    readonly property bool inLobby: Backend.mainViewModel.connected && !Backend.mainViewModel.gameStarted && Backend.mainViewModel.roomId === 0
    property var lobbyLObject: null
    readonly property var lobbyNavModel: [
        { name: "Rooms", title: i18n("Rooms"), icon: "view-list-details", pages: ["Rooms"] },
        { name: "Chat", title: i18n("Chat"), icon: "dialog-messages", pages: ["Chat"] },
        { name: "Todo", title: i18n("TODO"), icon: "question", pages: ["Todo"] },
    ]

    onIsWidescreenChanged: updateNav()
    onInLobbyChanged: {
        updateNav();
        if (root.inLobby) {
            root.switchLobbyNav(0);
        } else {
            priv.destroyLobby();
        }
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
                when: Backend.mainViewModel.connected && Backend.mainViewModel.gameStarted && Backend.mainViewModel.roomId !== 0

                PropertyChanges {
                    root.pageStack.items: [root.createLuaPageByUrl(Backend.mainViewModel.gamePageUrl, { objectName: Backend.mainViewModel.gameViewModelName })]
                }
            }
        ]
    }

    pageStack {
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

    Kirigami.PagePool {
        id: lobbyPagePool
    }

    Loader {
        id: sidebarLoader
        source: Qt.resolvedUrl("lobby/Sidebar.qml")
        active: false
    }

    TaskAndErrorDialog {
        id: taskDialog
    }

    Connections {
        target: Backend.mainViewModel
        function onShowToast(message: string) {
            root.showPassiveNotification(message, 3000);
        }
        function onShowErrorDialog(message: string) {
            taskDialog.addError(message);
        }
        function onSetProgressDialogData(key: string, message: string, progress: int, cancelable: bool) {
            taskDialog.setTaskData(key, message, progress, cancelable);
        }
        function onClearProgressDialogData(key: string) {
            taskDialog.removeTask(key);
        }
    }

    // TODO: these functions are lobby-specific, or, only useful when there is navigator
    QtObject {
        id: priv

        function ensureLobbyLObject() {
            if (root.lobbyLObject) {
                return;
            }
            const lobject = Qt.createComponent("org.kde.ktabletop", "LuaObject");
            root.lobbyLObject = lobject.createObject(root, { opts: { objectName: Backend.mainViewModel.lobbyViewModelName } });
        }

        function getPage(name) {
            ensureLobbyLObject();
            const url = Qt.resolvedUrl("lobby/" + name + "Page.qml");
            let page = lobbyPagePool.pageForUrl(url);
            if (page) {
                page.d = root.lobbyLObject;
            } else {
                page = lobbyPagePool.loadPageWithProperties(url, { d: root.lobbyLObject });
            }
            return page;
        }

        function destroyLobby() {
            lobbyPagePool.clear();
            if (root.lobbyLObject) {
                root.lobbyLObject.destroy();
                root.lobbyLObject = null;
            }
        }

        function switchToPage(page, depth) {
            const pages = Array.isArray(page) ? page : [page];
            const pageStack = root.pageStack;
            while (pageStack.layers.depth > 1) {
                pageStack.layers.pop();
            }
            if (pageStack.depth > 0) {
                while (pageStack.depth > Math.max(depth, 1)) {
                    pageStack.pop();
                }
                return pageStack.replace(pages);
            }
            let last = null;
            for (const p of pages) {
                last = pageStack.push(p);
            }
            return last;
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

    function updateNav() {
        if (footer) {
            footer.destroy();
            footer = null;
        }
        if (!root.inLobby) {
            root.globalDrawer = null;
            sidebarLoader.active = false;
            return;
        }
        if (root.isWidescreen) {
            sidebarLoader.active = true;
            root.globalDrawer = sidebarLoader.item;
        } else {
            sidebarLoader.active = false;
            root.globalDrawer = null;
            footer = Qt.createComponent(Qt.resolvedUrl("lobby/BottomToolbar.qml")).createObject(root);
        }
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

    // used by navigators
    function switchLobbyNav(index) {
        const item = root.lobbyNavModel[index];
        return priv.switchToPage(item.pages.map(n => priv.getPage(n)), item.pages.length);
    }

    function lobbyNavActive(name) {
        return pageStack.items.length > 0 && pageStack.items[0].objectName === name;
    }

    Component.onCompleted: {
        updateNav();
    }
}
