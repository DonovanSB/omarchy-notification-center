import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: root

  property string app: ""
  property string appIcon: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  property string preview: ""
  property string glyph: ""
  property double timestamp: 0
  property double now: 0
  property int urgency: 1
  property bool showBody: true
  property bool showPreview: true
  property bool unread: false
  property bool fullText: false
  property int remaining: 0
  property int groupUnread: 0
  property bool groupUrgent: false
  readonly property bool stacked: remaining > 0
  readonly property bool markedUrgent: urgency === 2 || (stacked && groupUrgent)
  readonly property bool markedUnread: unread || (stacked && groupUnread > 0)
  signal expandGroupRequested()
  signal textExpansionRequested()

  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal clicked()
  signal removeRequested()

  readonly property bool hovered: hover.hovered
  readonly property string iconSource: image !== "" ? resolve(image) : resolve(appIcon)
  readonly property bool hasIcon: iconSource !== "" && icon.status !== Image.Error
  readonly property string initial: app === "" ? "?" : app.charAt(0).toUpperCase()
  readonly property bool hasPreview: showPreview && preview !== "" && previewImage.status !== Image.Error

  readonly property string cleanBody: String(body || "")
    .replace(/<img[^>]*>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim()

  readonly property string cleanSummary: String(summary || "")
    .replace(/<img[^>]*>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim()

  readonly property string when: {
    var age = Math.max(0, now - timestamp)
    if (age < 60000) return "now"
    if (age < 3600000) return Math.floor(age / 60000) + " min ago"
    return Qt.formatDateTime(new Date(timestamp), age < 86400000 ? "HH:mm" : "d MMM · HH:mm")
  }

  function resolve(icon) {
    var value = String(icon || "")
    if (value === "") return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  implicitHeight: card.implicitHeight + (remaining > 0 ? Style.space(12) : 0)

  // Folded groups are one interactive card with two inset cards behind it.
  Rectangle {
    visible: root.remaining > 0
    x: Style.space(14)
    y: card.implicitHeight - Style.space(8)
    width: parent.width - Style.space(28)
    height: Style.space(15)
    radius: Style.space(8)
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
  }
  Rectangle {
    visible: root.remaining > 1
    x: Style.space(24)
    y: card.implicitHeight - Style.space(4)
    width: parent.width - Style.space(48)
    height: Style.space(15)
    radius: Style.space(8)
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
  }

  HoverHandler { id: hover }

  Rectangle {
    id: card
    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: texts.implicitHeight + Style.space(20)

    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b,
                   root.hovered ? 0.11 : 0.06)
    radius: Style.space(12)

    Behavior on color { ColorAnimation { duration: 90 } }

    Rectangle {
      visible: root.markedUrgent
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.margins: Style.space(6)
      width: Style.space(3)
      radius: width / 2
      color: Color.urgent
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) root.removeRequested()
        else root.clicked()
      }
    }

    Item {
      id: avatar
      anchors.left: parent.left
      anchors.leftMargin: Style.space(12)
      anchors.top: parent.top
      anchors.topMargin: Style.space(10)
      width: Style.space(32)
      height: Style.space(32)

      Rectangle {
        anchors.fill: parent
        radius: Style.space(9)
        visible: !root.hasIcon
        color: root.foreground
        opacity: 0.12
      }

      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        visible: !root.hasIcon && root.glyph === ""
        text: root.initial
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        color: root.foreground
        opacity: 0.7
      }

      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        visible: !root.hasIcon && root.glyph !== ""
        text: root.glyph
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        color: root.foreground
        opacity: 0.8
      }

      Image {
        id: icon
        anchors.fill: parent
        visible: root.hasIcon
        source: root.iconSource
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
      }
    }

    Column {
      id: texts
      anchors.left: avatar.right
      anchors.leftMargin: Style.space(10)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(12)
      anchors.top: parent.top
      anchors.topMargin: Style.space(10)
      spacing: Style.space(1)

      Item {
        width: parent.width
        height: Style.space(24)

        Text {
          id: appLabel
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(0, parent.width - whenLabel.implicitWidth - controls.width - Style.space(12))
          text: root.app + (root.stacked ? " · " + (root.remaining + 1) : "")
          textFormat: Text.PlainText
          elide: Text.ElideRight
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          color: root.markedUrgent ? Color.urgent : root.foreground
          opacity: 0.65
        }
        Text {
          id: whenLabel
          anchors.right: controls.left
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          text: root.when
          textFormat: Text.PlainText
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          color: root.foreground
          opacity: 0.45
        }
        Row {
          id: controls
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)
          ChevronButton {
            expanded: root.fullText && !root.stacked
            tooltipText: root.stacked ? "Expand " + (root.remaining + 1) + " notifications"
              : root.fullText ? "Collapse message" : "Show full message"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.stacked ? root.expandGroupRequested() : root.textExpansionRequested()
          }
          CloseButton {
            tooltipText: root.stacked ? "Dismiss all " + (root.remaining + 1) + " notifications from " + root.app : "Dismiss notification"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.removeRequested()
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        visible: root.summary !== ""
        text: root.cleanSummary
        elide: Text.ElideRight
        wrapMode: Text.WordWrap
        maximumLineCount: root.fullText && !root.stacked ? 1000 : 2
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        color: root.foreground
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        visible: root.showBody && root.cleanBody !== ""
        text: root.cleanBody
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        maximumLineCount: root.fullText && !root.stacked ? 1000 : 2
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        color: root.foreground
        opacity: 0.75
      }

      Item {
        width: parent.width
        height: root.hasPreview
          ? Math.min(width * 9 / 16, Style.space(104)) + Style.space(6) : 0
        visible: root.hasPreview

        Image {
          id: previewImage
          anchors.fill: parent
          anchors.topMargin: Style.space(6)
          source: root.showPreview ? root.preview : ""
          sourceSize.width: Math.round(width * 2)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          smooth: true

          layer.enabled: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: previewMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
          }
        }

        Rectangle {
          id: previewMask
          anchors.fill: previewImage
          radius: Style.space(8)
          color: "black"
          visible: false
          layer.enabled: true
          layer.smooth: true
        }
      }
    }

    Rectangle {
      visible: root.markedUnread && !root.markedUrgent
      anchors.left: parent.left
      anchors.leftMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(5)
      height: width
      radius: width / 2
      color: Color.accent
    }
  }
}
