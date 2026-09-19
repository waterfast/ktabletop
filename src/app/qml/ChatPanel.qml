import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

ListView {
    id: root
    property ListModel messages: ListModel {}
    required property int selfId

    model: messages
    spacing: Kirigami.Units.smallSpacing
    clip: true
    verticalLayoutDirection: ListView.BottomToTop

    onCountChanged: {
        currentIndex = 0
        positionViewAtIndex(0, ListView.Beginning);
    }

    delegate: RowLayout {
        id: msgDelegate
        required property var model
        required property int index
        width: root.width
        spacing: 0

        readonly property var nextMessage: index + 1 < root.messages.count
            ? root.messages.get(index + 1)
            : null
        readonly property bool grouped: nextMessage !== null
            && nextMessage.id === model.id
            && model.timestamp - nextMessage.timestamp <= 30
        readonly property bool own: model.id === root.selfId
        readonly property int maxBubbleWidth: Math.min(width * 0.9, Kirigami.Units.gridUnit * 60)

        Item {
            Layout.fillWidth: true
            visible: msgDelegate.own
        }

        Item {
            Layout.preferredWidth: Kirigami.Units.largeSpacing
            visible: !msgDelegate.own
        }

        QQC2.Control {
            id: bubble
            Layout.maximumWidth: msgDelegate.maxBubbleWidth
            Layout.topMargin: msgDelegate.grouped ? 0 : Kirigami.Units.smallSpacing

            leftPadding: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
            rightPadding: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
            topPadding: Kirigami.Units.largeSpacing
            bottomPadding: Kirigami.Units.largeSpacing

            contentItem: ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    visible: !msgDelegate.grouped
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: model.username
                        font.bold: true
                        color: msgDelegate.own
                            ? Kirigami.Theme.linkColor
                            : Kirigami.Theme.textColor
                    }

                    QQC2.Label {
                        text: Qt.formatTime(new Date(model.timestamp * 1000), "hh:mm")
                        opacity: 0.5
                        font: Kirigami.Theme.smallFont
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    text: model.text
                    textFormat: Text.MarkdownText
                    wrapMode: Text.Wrap
                }
            }

            background: Kirigami.ShadowedRectangle {
                Kirigami.Theme.colorSet: Kirigami.Theme.View
                Kirigami.Theme.inherit: false
                color: msgDelegate.own
                    ? Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.15)
                    : Kirigami.Theme.backgroundColor
                radius: Kirigami.Units.cornerRadius
                shadow {
                    size: Kirigami.Units.smallSpacing
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
                }
            }
        }

        Item {
            Layout.fillWidth: true
            visible: !msgDelegate.own
        }

        Item {
            Layout.preferredWidth: Kirigami.Units.largeSpacing
            visible: msgDelegate.own
        }
    }

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: root.count === 0
        icon.name: "dialog-messages"
        text: i18n("No messages yet")
    }
}
