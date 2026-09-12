import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property ListModel messages: ListModel {}
    required property int selfId
    signal sendRequested(string text)

    spacing: Kirigami.Units.smallSpacing

    QQC2.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {   
            id: listView
            model: root.messages
            spacing: Kirigami.Units.smallSpacing
            clip: true
            verticalLayoutDirection: ListView.BottomToTop

            onCountChanged: {
                Qt.callLater(() => {
                    listView.currentIndex = 0
                    listView.positionViewAtIndex(0, ListView.Beginning);
                });
            }

            delegate: ColumnLayout {
                id: msgDelegate
                width: listView.width
                spacing: 0

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: model.username
                        font.bold: true
                        color: model.id === root.selfId
                            ? Kirigami.Theme.linkColor
                            : Kirigami.Theme.textColor
                    }

                    QQC2.Label {
                        text: Qt.formatTime(new Date(model.timestamp * 1000), "hh:mm")
                        opacity: 0.5
                        font: Kirigami.Theme.smallFont
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    text: model.text
                    wrapMode: Text.Wrap
                }
            }

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 4
                visible: listView.count === 0
                icon.name: "dialog-messages"
                text: i18n("No messages yet")
            }
        }
    }
    
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        QQC2.TextField {
            id: input
            Layout.fillWidth: true
            placeholderText: i18n("Write a message…")
            onAccepted: root._send()
        }

        QQC2.Button {
            icon.name: "document-send"
            enabled: input.text.trim().length > 0
            onClicked: root._send()
        }
    }

    function _send() {
        const text = input.text.trim();
        if (text.length === 0) return;
        
        root.sendRequested(text);
        input.text = "";
        input.forceActiveFocus();
    }
}
