import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Ui

// One centered vector, rotated around its center for both expansion states.
PanelActionButton {
  id: root
  property bool expanded: false
  size: Style.space(22)
  iconText: ""

  Shape {
    anchors.centerIn: parent
    width: Style.space(10)
    height: Style.space(6)
    rotation: root.expanded ? 180 : 0

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.enabled ? root.foreground : Qt.darker(root.foreground, 2)
      strokeWidth: Math.max(1, Style.space(1.4))
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      startX: Style.space(1)
      startY: Style.space(1)
      PathLine { x: Style.space(5); y: Style.space(5) }
      PathLine { x: Style.space(9); y: Style.space(1) }
    }
  }
}
