import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  property string app: ""
  property int count: 0
  property int unread: 0
  property bool urgent: false
  property bool expanded: false
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  signal toggleRequested()
  signal clearRequested()
  implicitHeight: Style.space(42)

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: Style.space(6)
    radius: Style.space(8)
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, hover.containsMouse ? 0.09 : 0)
    MouseArea {
      id: hover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggleRequested()
    }
    Text {
      id: label
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8)
      anchors.right: counter.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: root.app
      textFormat: Text.PlainText
      elide: Text.ElideRight
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      color: root.urgent ? Color.urgent : root.foreground
    }
    Rectangle {
      id: counter
      anchors.right: collapse.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      width: countText.implicitWidth + Style.space(14)
      height: Style.space(22)
      radius: height / 2
      color: root.unread > 0 ? Color.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
      Text {
        id: countText
        anchors.centerIn: parent
        text: root.count
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        color: root.unread > 0 ? Color.background : root.foreground
      }
    }
    ChevronButton {
      id: collapse
      anchors.right: clear.left
      anchors.rightMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
      expanded: true
      tooltipText: "Collapse group"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.toggleRequested()
    }
    CloseButton {
      id: clear
      anchors.right: parent.right
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      tooltipText: "Clear notifications from " + root.app
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.clearRequested()
    }
    PanelToolTip {
      visible: hover.containsMouse
      text: root.count + " notifications · " + root.unread + " unread" + (root.urgent ? " · Contains urgent notifications" : "")
      fontFamily: root.fontFamily
    }
  }
}
