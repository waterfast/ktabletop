// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick

Item {
    id: root

    property int boardX: 1
    property int boardY: 1
    property string piece: "."
    property bool flipped: false
    property int cellSize: 62

    width: cellSize
    height: cellSize
    x: (root.flipped ? 8 - root.boardX : root.boardX - 1) * root.cellSize
    y: (root.flipped ? 8 - root.boardY : root.boardY - 1) * root.cellSize

    Behavior on x {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutQuad
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutQuad
        }
    }

    readonly property string fileName: {
        if (!root.piece || root.piece === ".") {
            return "";
        }
        const names = { "R": "rook", "N": "knight", "B": "bishop", "Q": "queen", "K": "king", "P": "pawn" };
        const white = root.piece === root.piece.toUpperCase();
        return (white ? "white_" : "black_") + names[root.piece.toUpperCase()] + ".svg";
    }

    Image {
        anchors.centerIn: parent
        width: 64
        height: 64
        source: root.fileName === "" ? "" : Qt.resolvedUrl("../assets/image/" + root.fileName)
    }
}
