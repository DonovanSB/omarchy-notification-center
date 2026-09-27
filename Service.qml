import QtQuick
import Quickshell
import Quickshell.Io

// One archive owner for all monitors. Mutations are serialized before reloads.
Item {
  id: root
  visible: false
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null
  property string omarchyPath: ""
  property int keepDays: 30
  property int maxItems: 1000
  property bool showPreview: true
  property var entries: []
  property double lastSeen: 0
  property bool loaded: false
  property string error: ""
  property var jobs: []
  property int revision: 0
  property int loadRevision: 0
  readonly property bool watching: watchProc.running
  readonly property int unread: entries.filter(function(e) { return e.timestamp > root.lastSeen }).length
  readonly property string script: Qt.resolvedUrl("bin/notification-center").toString().replace(/^file:\/\//, "")
  readonly property var storeEnvironment: ({
    "NC_KEEP_DAYS": String(keepDays), "NC_MAX_ITEMS": String(maxItems),
    "NC_PREVIEWS": showPreview ? "1" : "0"
  })
  property bool doNotDisturb: false
  property bool dndAvailable: false
  signal panelRequested(string mode)
  signal entryAdded(var entry)
  signal entriesReset()

  function command(args) { return [script].concat(args) }
  function load() {
    if (listProc.running || mutation.running || jobs.length) return
    loadRevision = revision
    listProc.command = command(["list", String(maxItems)])
    listProc.running = true
  }
  function enqueue(args) {
    revision++
    jobs = jobs.concat([args])
    runNext()
  }
  function runNext() {
    if (mutation.running) return
    if (!jobs.length) { load(); return }
    var args = jobs[0]
    jobs = jobs.slice(1)
    mutation.command = command(args)
    mutation.running = true
  }
  function markSeen() {
    lastSeen = Date.now()
    seenTimer.restart()
  }
  function removeKeys(keys) {
    if (!keys.length) return
    entries = entries.filter(function(e) { return keys.indexOf(e.key) < 0 })
    entriesReset()
    enqueue(["remove"].concat(keys))
  }
  function remove(key) { removeKeys([key]) }
  function clearAll() {
    entries = []
    entriesReset()
    enqueue(["clear", String(Date.now())])
  }
  function absorb(line) {
    if (mutation.running || jobs.length) return
    try {
      var entry = JSON.parse(line)
      if (!entry || !entry.key) return
      var next = entries.filter(function(e) { return e.key !== entry.key })
      next.push(entry)
      next.sort(function(a, b) { return b.timestamp - a.timestamp })
      entries = next.slice(0, maxItems)
      revision++
      entryAdded(entry)
    } catch (e) { error = "Could not read a notification" }
  }
  onKeepDaysChanged: restartSettings.restart()
  onMaxItemsChanged: restartSettings.restart()
  onShowPreviewChanged: restartSettings.restart()
  Timer {
    id: restartSettings
    interval: 300
    onTriggered: {
      if (watchProc.running) watchProc.running = false
      restartWatch.restart()
      root.load()
    }
  }
  Process {
    id: watchProc
    command: root.command(["watch"])
    environment: root.storeEnvironment
    running: true
    stdout: SplitParser { onRead: function(line) { root.absorb(line) } }
    onExited: restartWatch.restart()
  }
  Timer {
    id: restartWatch
    interval: 2000
    onTriggered: if (!watchProc.running) watchProc.running = true
  }
  Timer { interval: 10000; running: true; repeat: true; onTriggered: root.load() }
  Timer { id: seenTimer; interval: 200; onTriggered: root.enqueue(["seen", String(root.lastSeen)]) }
  Process {
    id: listProc
    environment: root.storeEnvironment
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.loadRevision !== root.revision) { reloadSoon.restart(); return }
        try {
          var data = JSON.parse(text)
          if (!Array.isArray(data)) throw new Error("invalid archive")
          root.loaded = true
          root.error = ""
          if (JSON.stringify(data) !== JSON.stringify(root.entries)) {
            root.entries = data
            root.entriesReset()
          }
        } catch (e) { root.error = "Could not read notification history" }
      }
    }
  }
  Timer { id: reloadSoon; interval: 100; onTriggered: root.load() }
  Process {
    id: mutation
    environment: root.storeEnvironment
    onExited: function(code) {
      if (code !== 0) root.error = "Could not save the change"
      Qt.callLater(root.runNext)
    }
  }
  Process {
    id: seenProc
    command: root.command(["seen"])
    environment: root.storeEnvironment
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.lastSeen = Math.max(root.lastSeen, Number(JSON.parse(text).seen) || 0) } catch (e) {}
      }
    }
  }
  function readDnd() {
    if (!dndReader.running && !dndToggle.running) dndReader.running = true
  }
  function toggleDnd() {
    if (!dndToggle.running) dndToggle.running = true
  }
  function acceptDnd(text) {
    var value = text.trim()
    dndAvailable = value === "on" || value === "off"
    if (dndAvailable) doNotDisturb = value === "on"
  }
  Process {
    id: dndReader
    command: ["omarchy-shell", "notifications", "dndState"]
    stdout: StdioCollector { onStreamFinished: root.acceptDnd(text) }
  }
  Process {
    id: dndToggle
    command: ["omarchy-shell", "notifications", "toggleDnd"]
    stdout: StdioCollector { onStreamFinished: root.acceptDnd(text) }
  }
  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/notifications.json"
    watchChanges: true
    onFileChanged: { reload(); root.readDnd() }
  }
  Timer { interval: 10000; running: true; repeat: true; onTriggered: root.readDnd() }
  Process { id: dismissAll; command: ["omarchy-shell", "notifications", "dismissAll"] }
  function dismissPopups() { if (!dismissAll.running) dismissAll.running = true }
  Component.onCompleted: { load(); readDnd() }
  IpcHandler {
    target: "donovan.notification-center"
    function toggle(): void { root.panelRequested("toggle") }
    function open(): void { root.panelRequested("open") }
    function close(): void { root.panelRequested("close") }
    function toggleDnd(): void { root.toggleDnd() }
  }
  IpcHandler {
    target: "donovan.notification-center.archive"
    function reload(): void { root.load() }
    function state(): string {
      return JSON.stringify({entries: root.entries.length, unread: root.unread,
        applications: new Set(root.entries.map(function(e) { return String(e.app).trim().toLowerCase() })).size,
        watching: root.watching, loaded: root.loaded, dnd: root.doNotDisturb, dndAvailable: root.dndAvailable, error: root.error})
    }
  }
}
