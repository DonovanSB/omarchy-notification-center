import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Ui

// Match the chevron's stroke, optical size and centered 22-unit hit area.
PanelActionButton {
  id: root
  size: Style.space(22)
  iconText: ""

  Shape {
    anchors.centerIn: parent
    width: Style.space(10)
    height: Style.space(10)

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.enabled ? root.foreground : Qt.darker(root.foreground, 2)
      strokeWidth: Math.max(1, Style.space(1.4))
      capStyle: ShapePath.RoundCap
      startX: Style.space(1)
      startY: Style.space(1)
      PathLine { x: Style.space(9); y: Style.space(9) }
      PathMove { x: Style.space(1); y: Style.space(9) }
      PathLine { x: Style.space(9); y: Style.space(1) }
    }
  }
}
