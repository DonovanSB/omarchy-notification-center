// Pure model functions, shared by QML and the behavioral tests.
function appKey(entry) {
  return String(entry.app || "Unknown application").trim().toLowerCase() || "unknown application"
}
function groups(entries, query, readMark) {
  var needle = String(query || "").trim().toLowerCase()
  var byApp = Object.create(null)
  var result = []
  entries.slice().sort(function(a, b) { return b.timestamp - a.timestamp }).forEach(function(entry) {
    if (needle && [entry.app, entry.summary, entry.body].join(" ").toLowerCase().indexOf(needle) < 0) return
    var key = appKey(entry)
    if (!byApp[key]) {
      byApp[key] = {key: key, app: String(entry.app || "Unknown application").trim(),
        entries: [], unread: 0, urgent: false}
      result.push(byApp[key])
    }
    var group = byApp[key]
    group.entries.push(entry)
    if (entry.timestamp > readMark) group.unread++
    if (entry.urgency === 2) group.urgent = true
  })
  return result
}
function flatRows(entries, query, readMark, expanded, collapsed) {
  var result = []
  groups(entries, query, readMark).forEach(function(group) {
    var isExpanded = query.trim() !== "" || (Object.prototype.hasOwnProperty.call(expanded, group.key)
      ? expanded[group.key] : !collapsed)
    function row(entry, header) {
      return {header: header, stacked: !isExpanded && group.entries.length > 1,
        cursorKey: header || (!isExpanded && group.entries.length > 1) ? "group:" + group.key : "entry:" + entry.key, groupKey: group.key, groupCount: group.entries.length,
        groupUnread: group.unread, groupUrgent: group.urgent, expanded: isExpanded,
        key: String(entry.key || ""), app: group.app, appIcon: String(entry.appIcon || ""),
        summary: String(entry.summary || ""), body: String(entry.body || ""),
        image: String(entry.image || ""), preview: String(entry.preview || ""),
        file: String(entry.file || ""), glyph: String(entry.glyph || ""),
        urgency: Number(entry.urgency || 0), timestamp: Number(entry.timestamp || 0)}
    }
    if (isExpanded && group.entries.length > 1) result.push(row(group.entries[0], true))
    var visible = isExpanded ? group.entries : group.entries.slice(0, 1)
    visible.forEach(function(entry) { result.push(row(entry, false)) })
  })
  return result
}
function keysForDismissal(entries, row, query) {
  if (!row.header && !row.stacked) return [row.key]
  var matching = groups(entries, query, 0)
  for (var i = 0; i < matching.length; i++) {
    if (matching[i].key === row.groupKey) return matching[i].entries.map(function(e) { return e.key })
  }
  return []
}
if (typeof module !== "undefined") module.exports = {appKey: appKey, groups: groups, flatRows: flatRows, keysForDismissal: keysForDismissal}
