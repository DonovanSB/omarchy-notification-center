import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

import "components"
import "Grouping.js" as Grouping

Panel {
  id: root

  moduleName: "donovan.notification-center"
  manageIpc: false

  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int panelWidth: setting("panelWidth", 440)
  readonly property int listHeight: setting("listHeight", 0)
  readonly property string badge: setting("badge", "Dot")
  readonly property int keepDays: setting("keepDays", 30)
  readonly property int maxItems: setting("maxItems", 1000)
  readonly property string clickAction: setting("clickAction", "Auto")
  readonly property bool showBody: setting("showBody", true)
  readonly property bool collapsed: setting("collapsed", true)
  property var expandedGroups: ({})
  property var expandedMessages: ({})
  onCollapsedChanged: rebuild()
  readonly property bool showPreview: setting("showPreview", true)

  readonly property bool dnd: store ? store.doNotDisturb : false
  function toggleDnd() { if (store) store.toggleDnd() }

  property var store: null

  function bindStore() {
    if (store) {
      pushSettings()
      return
    }
    var host = bar && bar.shell ? bar.shell : null
    if (!host || typeof host.serviceFor !== "function") return
    var s = host.serviceFor("donovan.notification-center")
    if (!s) return
    store = s
    pushSettings()
    rebuild()
  }

  function pushSettings() {
    if (!store) return
    store.keepDays = keepDays
    store.maxItems = maxItems
    store.showPreview = showPreview
  }

  onBarChanged: bindStore()
  onKeepDaysChanged: pushSettings()
  onMaxItemsChanged: pushSettings()
  onShowPreviewChanged: pushSettings()

  Timer {
    interval: 200
    running: root.store === null
    repeat: true
    onTriggered: root.bindStore()
  }

  Connections {
    target: root.store
    function onEntryAdded(entry) { root.handleEntryAdded(entry) }
    function onEntriesReset() { root.rebuild() }
    function onPanelRequested(mode) {
      if (mode === "close") { root.close(); return }
      var focused = Hyprland.focusedMonitor
      if (focused && popup.screen && focused.name !== popup.screen.name) { root.close(); return }
      mode === "toggle" ? root.toggle() : root.open()
    }
  }

  readonly property var entries: store ? store.entries : []
  property string filter: ""
  property double readMark: 0
  readonly property bool loaded: store ? store.loaded : false
  property bool searching: false
  property double now: Date.now()

  readonly property int unread: store ? store.unread : 0
  readonly property double lastSeen: store ? store.lastSeen : 0

  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = Date.now()
  }

  function startSearch() {
    searching = true
    Qt.callLater(function() { if (root.searching) search.forceActiveFocus() })
  }

  function endSearch() {
    searching = false
    filter = ""
    search.text = ""
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }

  Process { id: focusProc }

  function remove(key) { if (store) store.remove(key) }
  function removeRow(row) {
    if (store) store.removeKeys(Grouping.keysForDismissal(entries, row, filter))
  }
  function clearGroup(key) {
    // A search limits what is shown and what its group-clear button removes.
    var matching = Grouping.groups(entries, filter, readMark)
    for (var i = 0; i < matching.length; i++) {
      if (matching[i].key !== key) continue
      var keys = matching[i].entries.map(function(e) { return e.key })
      if (store) store.removeKeys(keys)
      break
    }
  }
  function clearAll() {
    if (store) store.clearAll()
    if (store) store.dismissPopups()
  }
  function toggleGroup(key) {
    var next = Object.assign({}, expandedGroups)
    next[key] = Object.prototype.hasOwnProperty.call(next, key) ? !next[key] : collapsed
    expandedGroups = next
    rebuild()
  }
  function toggleMessage(key) {
    var next = Object.assign({}, expandedMessages)
    next[key] = !next[key]
    expandedMessages = next
  }
  function handleEntryAdded(entry) {
    if (root.opened && store) store.markSeen()
    rebuild()
  }
  ListModel { id: rows }
  function rebuild() {
    if (!rows) return
    var selectedKey = list.currentIndex >= 0 && list.currentIndex < rows.count
      ? rows.get(list.currentIndex).cursorKey : ""
    rows.clear()
    var result = Grouping.flatRows(entries, filter, readMark, expandedGroups, collapsed)
    var selected = -1
    result.forEach(function(row, index) {
      rows.append(row)
      if (row.cursorKey === selectedKey) selected = index
    })
    list.currentIndex = selected
  }
  function moveCursor(dx, dy) {
    if (!rows.count) return
    list.currentIndex = Math.max(0, Math.min(rows.count - 1, list.currentIndex + dy))
    var row = rows.get(list.currentIndex)
    if (dx && row.groupCount > 1 && row.expanded !== (dx > 0)) {
      var groupKey = row.groupKey
      toggleGroup(groupKey)
      for (var i = 0; i < rows.count; i++) {
        if (rows.get(i).cursorKey === "group:" + groupKey) { list.currentIndex = i; break }
      }
    } else if (dx && row.groupCount === 1 && !!expandedMessages[row.key] !== (dx > 0)) {
      toggleMessage(row.key)
    }
    list.positionViewAtIndex(list.currentIndex, ListView.Contain)
  }
  function activateCursor() {
    if (list.currentIndex < 0 || list.currentIndex >= rows.count) return
    var row = rows.get(list.currentIndex)
    (row.header || row.stacked) ? toggleGroup(row.groupKey) : activate(row)
  }
  function deleteCursor() {
    if (list.currentIndex < 0 || list.currentIndex >= rows.count) return
    var row = rows.get(list.currentIndex)
    removeRow(row)
  }

  onFilterChanged: rebuild()

  function activate(row) {
    if (!row || clickAction === "Nothing") return
    if (clickAction === "Auto" && row.file !== "") {
      Quickshell.execDetached(["xdg-open", row.file])
      root.close()
      return
    }
    if (!/^[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}$/.test(row.app)) return
    focusProc.command = [root.omarchyPath + "/bin/omarchy-hyprland-focus-app", row.app]
    focusProc.running = true
    root.close()
  }

  Component.onCompleted: bindStore()

  onOpenedChanged: {
    if (!opened) {
      searching = false
      filter = ""
      search.text = ""
      return
    }
    now = Date.now()
    if (store) { store.load(); store.readDnd() }
    readMark = lastSeen
    expandedGroups = ({})
    expandedMessages = ({})
    rebuild()
    if (store) store.markSeen()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    bar: root.bar

    text: root.dnd ? "\uDB80\uDC9B" : "\uDB80\uDC9A"
    dimmed: root.dnd

    active: root.badge === "Highlight" && root.unread > 0
    activeColor: Color.accent
    tooltipText: {
      if (root.dnd) return "Do Not Disturb · " + root.unread + " unread"
      if (root.unread === 1) return "1 unread notification"
      if (root.unread > 1) return root.unread + " unread notifications"
      return "Notifications"
    }

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.toggleDnd()
        return
      }
      root.toggle()
    }
  }

  Item {
    id: rightAnchor
    anchors.top: button.top
    anchors.bottom: button.bottom
    x: 1000000
    width: 1
    visible: false
  }

  Rectangle {
    id: dot
    visible: root.badge === "Dot" && root.unread > 0
    anchors.right: button.right
    anchors.rightMargin: Style.space(3)
    anchors.top: button.top
    anchors.topMargin: Style.space(5)
    width: Style.space(6)
    height: width
    radius: width / 2
    color: Color.accent
  }

  Rectangle {
    id: countBadge
    visible: root.badge === "Count" && root.unread > 0
    anchors.right: button.right
    anchors.rightMargin: Style.space(1)
    anchors.top: button.top
    anchors.topMargin: Style.space(3)
    width: Math.max(countText.implicitWidth + Style.space(6), Style.space(12))
    height: Style.space(12)
    radius: height / 2
    color: Color.accent

    Text {
      textFormat: Text.PlainText
      id: countText
      anchors.centerIn: parent
      text: root.unread > 99 ? "99+" : String(root.unread)
      font.family: root.fontFamily
      font.pixelSize: Math.max(8, Style.font.caption - Style.space(3))
      font.bold: true
      color: Color.background
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: rightAnchor
    bar: root.bar
    owner: root
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(root.panelWidth))
    contentHeight: Math.round(Math.min(
      Math.max(popup.verticalContentInset, content.implicitHeight + popup.verticalContentInset),
      popup.usableCardHeight))

    readonly property real usableCardHeight: {
      if (barH >= screenH && root.bar && Number(root.bar.barSize) > 0)
        return Math.max(120, screenH - (Number(root.bar.barSize) + gap + margin))
      return availableCardHeight
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.searching
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
      onDeleteRequested: root.deleteCursor()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "/") root.startSearch()
      }

      Column {
        id: content
        anchors.fill: parent
        spacing: Style.space(8)

        Item {
          id: header
          width: parent.width
          height: Math.max(title.implicitHeight, actions.height)

          PanelSectionHeader {
            id: title
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "NOTIFICATIONS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            id: actions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            PanelActionButton {
              anchors.verticalCenter: parent.verticalCenter
              iconText: "\uDB80\uDF49"
              tooltipText: "Search notifications ( / )"
              foreground: root.searching ? Color.accent : root.foreground
              fontFamily: root.fontFamily
              visible: root.entries.length > 0
              onClicked: root.searching ? root.endSearch() : root.startSearch()
            }

            PanelActionButton {
              anchors.verticalCenter: parent.verticalCenter
              iconText: root.dnd ? "\uDB80\uDC9B" : "\uDB80\uDC9A"
              tooltipText: root.dnd ? "Turn off Do Not Disturb" : "Turn on Do Not Disturb"
              foreground: root.dnd ? Color.accent : root.foreground
              fontFamily: root.fontFamily
              enabled: root.store !== null && root.store.dndAvailable
              onClicked: root.toggleDnd()
            }

            Button {
              anchors.verticalCenter: parent.verticalCenter
              text: "Clear"
              tooltipText: "Clear all notifications"
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              enabled: root.entries.length > 0
              onClicked: root.clearAll()
            }
          }
        }

        TextField {
          id: search
          width: parent.width
          visible: root.searching
          placeholderText: "Search by app or message…"
          foreground: root.foreground
          onTextChanged: root.filter = text
          Keys.onEscapePressed: root.endSearch()
          Keys.onDownPressed: list.flick(0, -900)
          Keys.onUpPressed: list.flick(0, 900)
        }

        ListView {
          id: list
          width: parent.width
          readonly property int cap: {
                        var chrome = header.height + search.implicitHeight + foot.implicitHeight
                       + content.spacing * 3
            var available = Math.max(Style.space(60), popup.usableCardHeight - popup.verticalContentInset - chrome)
            return root.listHeight > 0 ? Math.min(Style.space(root.listHeight), available) : available
          }

          height: Math.min(contentHeight, cap)
          visible: rows.count > 0
          clip: true
          model: rows
          spacing: Style.space(6)
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { id: listScroll; policy: ScrollBar.AsNeeded }

          readonly property real lane: Style.space(10)

          currentIndex: -1
          highlightMoveDuration: 0
          highlight: Rectangle {
            radius: Style.space(10)
            color: "transparent"
            border.width: 1
            border.color: Color.accent
          }
          delegate: Loader {
            id: rowLoader
            required property var model
            width: list.width - list.lane
            height: item ? item.implicitHeight : 0
            sourceComponent: model.header ? groupHeader : notificationRow
            Component {
              id: groupHeader
              GroupHeader {
                width: rowLoader.width
                app: rowLoader.model.app
                count: rowLoader.model.groupCount
                unread: rowLoader.model.groupUnread
                urgent: rowLoader.model.groupUrgent
                expanded: rowLoader.model.expanded
                foreground: root.foreground
                fontFamily: root.fontFamily
                onToggleRequested: root.toggleGroup(rowLoader.model.groupKey)
                onClearRequested: root.clearGroup(rowLoader.model.groupKey)
              }
            }
            Component {
              id: notificationRow
              NotificationRow {
                width: rowLoader.width
                remaining: rowLoader.model.stacked ? rowLoader.model.groupCount - 1 : 0
                groupUnread: rowLoader.model.groupUnread
                groupUrgent: rowLoader.model.groupUrgent
                fullText: !!root.expandedMessages[rowLoader.model.key]
                onTextExpansionRequested: root.toggleMessage(rowLoader.model.key)
                onExpandGroupRequested: root.toggleGroup(rowLoader.model.groupKey)
                app: rowLoader.model.app
                appIcon: rowLoader.model.appIcon
                summary: rowLoader.model.summary
                body: rowLoader.model.body
                image: rowLoader.model.image
                preview: rowLoader.model.preview
                glyph: rowLoader.model.glyph
                timestamp: rowLoader.model.timestamp
                now: root.now
                urgency: rowLoader.model.urgency
                unread: rowLoader.model.timestamp > root.readMark
                showBody: root.showBody
                showPreview: root.showPreview
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: rowLoader.model.stacked ? root.toggleGroup(rowLoader.model.groupKey) : root.activate(rowLoader.model)
                onRemoveRequested: root.removeRow(rowLoader.model)
              }
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: rows.count === 0
          horizontalAlignment: Text.AlignHCenter
          topPadding: Style.space(22)
          bottomPadding: Style.space(22)
          text: root.store && root.store.error !== "" ? root.store.error : !root.loaded ? "Loading history…"
              : root.filter !== "" ? "No results for “" + root.filter + "”"
              : "You're all caught up\nNo notifications"
          wrapMode: Text.WordWrap
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          color: root.foreground
          opacity: 0.55
        }

        Text {
          textFormat: Text.PlainText
          id: foot
          width: parent.width
          visible: root.entries.length > 0 && root.filter === ""
          horizontalAlignment: Text.AlignHCenter
          topPadding: Style.space(2)
          text: {
            var count = root.entries.length
            var apps = Grouping.groups(root.entries, "", 0).length
            return count + (count === 1 ? " notification · " : " notifications · ")
              + apps + (apps === 1 ? " app · " : " apps · ")
              + root.keepDays + (root.keepDays === 1 ? " day" : " days")
          }
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          color: root.foreground
          opacity: 0.4
        }
      }
    }
  }
}
