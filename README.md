<h1 align="center">Notification Center</h1>

<p align="center">
  Grouped notifications, persistent history, and Do Not Disturb for Omarchy.
</p>

Adds a bell to the bar. Click it to browse notifications grouped by application,
search messages, or clear your history. Uses Omarchy's built-in notification service.

## Requirements

- Omarchy 4 (Quattro) with `omarchy.notifications` enabled
- `jq`, `inotify-tools`, and `file`
- Optional: ImageMagick for smaller image previews

## Install

```bash
omarchy plugin add https://github.com/DonovanSB/omarchy-notification-center.git --enable --yes
```

## Using it

| Control | What it does |
|---|---|
| **Stacked card** | Expand the application's notifications |
| **Message arrow** | Show or collapse the full text |
| **×** | Dismiss the selected message or collapsed group |
| **Clear** | Clear history from the panel and dismiss active popups |
| **Right-click the bell** | Toggle Do Not Disturb |

Press `/` to search and `Esc` to close. Settings include retention, unread badges,
image previews, and panel size.

Open from a shortcut or terminal:

```bash
omarchy-shell donovan.notification-center toggle
```

History is stored locally in `~/.local/state/donovan-notification-center/`
(or under `XDG_STATE_HOME`), keeping up to 1,000 entries for 30 days by default.
Dismissing an individual entry affects saved history; its active popup expires normally.

## Remove

```bash
omarchy plugin remove donovan.notification-center
```

Removal keeps your saved history. To disable the plugin without removing it,
use `omarchy plugin disable donovan.notification-center`.

## Development

```bash
node tests/grouping.test.cjs
python3 -m unittest discover -s tests -v
omarchy plugin validate .
```

## License

MIT. Based on work by [Jankees van Woezik](https://github.com/jankeesvw/omarchy-notification-center)
and [Shavanced](https://github.com/Shavanced/omarchy-notification-center-plugin).
