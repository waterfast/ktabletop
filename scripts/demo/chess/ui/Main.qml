// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ktabletop

Kirigami.Page {
    id: root

    required property LuaObject d

    readonly property bool blackView: root.d.selfRole === "black"
    readonly property int cellSize: 62
    readonly property var topPlayer: root.playerAt(root.blackView ? 0 : 1)
    readonly property var bottomPlayer: root.playerAt(root.blackView ? 1 : 0)

    function playerAt(index) {
        const players = root.d.players;
        return (players && players.length > index) ? players[index] : null;
    }

    function isSelected(bx, by) {
        const s = root.d.selected;
        return !!s && s.x === bx && s.y === by;
    }

    function isMovable(bx, by) {
        const points = root.d.movablePoints;
        if (!points) {
            return false;
        }
        for (let i = 0; i < points.length; i++) {
            if (points[i].x === bx && points[i].y === by) {
                return true;
            }
        }
        return false;
    }

    function isLastMove(bx, by) {
        const lm = root.d.lastMove;
        if (!lm) {
            return false;
        }
        return (lm.fromX === bx && lm.fromY === by) || (lm.x === bx && lm.y === by);
    }

    function boardX(dx) {
        return root.blackView ? 8 - dx : dx + 1;
    }

    function boardY(dy) {
        return root.blackView ? 8 - dy : dy + 1;
    }

    function findPieceIndex(bx, by) {
        for (let i = 0; i < pieceModel.count; i++) {
            const p = pieceModel.get(i);
            if (p.px === bx && p.py === by) {
                return i;
            }
        }
        return -1;
    }

    function syncBoard(board) {
        pieceModel.clear();
        if (!board) {
            return;
        }
        for (let by = 1; by <= 8; by++) {
            const row = board[by - 1];
            if (!row) {
                continue;
            }
            for (let bx = 1; bx <= 8; bx++) {
                const pc = row[bx - 1];
                if (pc && pc !== ".") {
                    pieceModel.append({ px: bx, py: by, pc: pc });
                }
            }
        }
    }

    function movePieceTo(data) {
        let ci = root.findPieceIndex(data.x, data.y);
        let fi = root.findPieceIndex(data.fromX, data.fromY);
        if (ci >= 0) {
            pieceModel.remove(ci);
            if (ci < fi) {
                fi -= 1;
            }
        }
        if (fi < 0) {
            return;
        }
        pieceModel.setProperty(fi, "px", data.x);
        pieceModel.setProperty(fi, "py", data.y);
        if (data.piece) {
            pieceModel.setProperty(fi, "pc", data.piece);
        }
    }

    function movePieceOut(data) {
        const i = root.findPieceIndex(data.x, data.y);
        if (i >= 0) {
            pieceModel.remove(i);
        }
    }

    ListModel {
        id: pieceModel
    }

    Connections {
        target: root.d

        function onSignalEmitted(name, data) {
            if (name === "SyncBoard") {
                root.syncBoard(data);
            } else if (name === "MovePieceTo") {
                root.movePieceTo(data);
            } else if (name === "MovePieceOut") {
                root.movePieceOut(data);
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing

        PlayerCard {
            Layout.alignment: Qt.AlignHCenter
            player: root.topPlayer
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: root.cellSize * 8
            implicitHeight: root.cellSize * 8

            Grid {
                anchors.fill: parent
                columns: 8

                Repeater {
                    model: 64

                    delegate: Item {
                        required property int index

                        width: root.cellSize
                        height: root.cellSize

                        readonly property int dx: index % 8
                        readonly property int dy: Math.floor(index / 8)
                        readonly property int bx: root.boardX(dx)
                        readonly property int by: root.boardY(dy)

                        Rectangle {
                            anchors.fill: parent
                            color: (dx + dy) % 2 === 0 ? "#ebecd0" : "#739552"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "#f5f682"
                            opacity: 0.5
                            visible: root.isLastMove(bx, by) || root.isSelected(bx, by)
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            radius: 10
                            color: "black"
                            opacity: 0.3
                            z: 9
                            visible: root.isMovable(bx, by)
                        }

                        TapHandler {
                            onTapped: root.d.invoke("clickCell", [bx, by])
                        }
                    }
                }
            }

            Repeater {
                model: pieceModel

                delegate: Piece {
                    required property var model
                    boardX: model.px
                    boardY: model.py
                    piece: model.pc
                    flipped: root.blackView
                    cellSize: root.cellSize
                }
            }
        }

        PlayerCard {
            Layout.alignment: Qt.AlignHCenter
            player: root.bottomPlayer
            isSelf: true
        }
    }

    Loader {
        id: promotionLoader
        anchors.centerIn: parent
        active: root.d.promotion !== null && root.d.promotion !== undefined
        sourceComponent: PromotionBox {
            pieceColor: root.d.selfRole
            onAccepted: root.d.invoke("accepted", [promotionResult])
        }
        onLoaded: item.open()
    }

    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: root.d.gameOver !== null && root.d.gameOver !== undefined
        z: 100

        QQC2.Label {
            anchors.centerIn: parent
            color: "white"
            font.pixelSize: 32
            text: {
                const result = root.d.gameOver;
                if (result === "white") {
                    return i18n("White wins");
                }
                if (result === "black") {
                    return i18n("Black wins");
                }
                return i18n("Draw");
            }
        }
    }

    Component.onCompleted: root.d.invoke("requestSync")
}
