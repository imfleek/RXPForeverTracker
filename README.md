<div align="center">

# 🧭 RXP ForeverTracker

**A scrollable, smarter quest tracker for WoW Forever, with your RestedXP guide built right in.**

[![Latest release](https://img.shields.io/github/v/release/imfleek/RXPForeverTracker?label=release&color=c9a24a)](https://github.com/imfleek/RXPForeverTracker/releases/latest)
![WoW Forever](https://img.shields.io/badge/WoW_Forever-16001-8b1a10)
[![License: MIT](https://img.shields.io/badge/license-MIT-4c7a3d)](LICENSE)

</div>

---

## 📦 How to Install

1. Download **`RXPForeverTracker.zip`** from the [latest release](https://github.com/imfleek/RXPForeverTracker/releases/latest).
2. Extract the `RXPForeverTracker` folder into:

   <table><tr><td><code>BattleNet/World of Warcraft/_forever_/Interface/AddOns/</code></td></tr></table>

### ✨ Highlights

- 🖱️ **Mouse-wheel scrolling** for Blizzard's own tracker, with an optional scrollbar. The tracker itself is kept as it is, inside a frame that scrolls, so long quest lists never run off the screen.
- 🗺️ **Zone sorting**: quests grouped under zone headers, with the closest quest first.
- 💰 **Rewards at a glance**: experience and gold after each quest title, a check on finished quests, and tooltips with objectives, rewards and the gold an item reward sells for.
- 📜 **Your RestedXP guide in the tracker**: the current and upcoming steps with click-to-use item and spell buttons, a waypoint arrow, back / restart / forward buttons (Shift+click for the previous or next zone guide), and a check to mark a step done.
- 🔗 **Links everywhere**: items, spells and quests in guide steps show their tooltips; Shift+click a quest to link it in chat.
- 📖 **Prerequisite Journal** (with Questie): for every quest still ahead in your guide, the prerequisites you are missing, where to do them, and which later guide does them on the way.
- ❓ **"Why did guide skip?"** (`/qt why`): a plain-words list of every guide and step move, who made it and why, ready to copy into a bug report.
- 🧹 **Orphaned quest cleanup**: quests your guide no longer uses, coloured by difficulty, with their zone, sortable, and abandoned one by one or all at once.
- 🎨 **Forever Style settings window** with search, profiles you can import and export, and per-page Defaults.

> **Optional Integrated addons:**
> - **RestedXP Guides**: guide steps in the tracker
> - **Questie**: quest giver, turn-in and objective locations, chains, attunement star, party progress, closest-quest sorting

## ⚙️ Settings: `/qt`

The categories are on the left of the settings window:

| Category | Pages |
| --- | --- |
| 📋 **Quest Tracker** | Quest list (lock, extra length, scrollbar, items, quest count, header colours) · Zone headers · Quest titles · Tooltips · Tracking and sorting (track mode, zone sort) |
| 🧭 **RXP Tracker** | Tracker settings (including Own window) · Waypoint arrow · Themes & guide (theme, status, choose, restart or reset guides) · Orphaned quests |
| 🪟 **Settings Window** | Text and font · Advanced · Background · Profiles (save, load, delete, import, export; starts on "Default") · Minimap button |

> 💡 **Tips**
> - Colours have presets, a custom colour and an opacity slider.
> - The search box finds any setting.
> - **Shift+right-click** the guide in the tracker to open this window; **right-click** opens the guide menu.

## Commands (Backup to /qt Config)

<details>
<summary><b>Show all commands</b></summary>

Type `/qt help` in game for this list.

### Quest tracker

| Command | What it does |
| --- | --- |
| `/qt` | Opens or closes the settings window. |
| `/qt config` | The same as `/qt`. |
| `/qt guide` | Opens the settings window at the guide (RXP Tracker) settings. |
| `/qt quests` | Opens the settings window at the quest tracker settings. |
| `/qt orphan` | Opens the settings window at Orphaned quests. |
| `/qt height <px>` | Sets how tall the quest list is (`0` = automatic). |
| `/qt scale <0.5-1.5>` | Sets the tracker's size. |
| `/qt step <px>` | Sets how far one turn of the mouse wheel scrolls. |
| `/qt zone` | Turns sorting quests by zone on or off. |
| `/qt sort` | Sorts the quests now. |
| `/qt lock` | Locks the tracker in place. |
| `/qt unlock` | Unlocks the tracker so you can drag it by the green bar. |
| `/qt reset` | Scrolls the tracker back to the top. |
| `/qt on` / `/qt off` | Turns the quest tracker on or off (then type `/reload`). |
| `/qt debug` | Opens the tracker's layout details in a window, to copy into a bug report. |

### RXP Tracker (needs RestedXP Guides)

| Command | What it does |
| --- | --- |
| `/qt toggle` | Shows the guide steps in the tracker, or brings back RestedXP's own windows. |
| `/qt <0-100>` or `/qt all` | Sets how many upcoming steps are shown. |
| `/qt steps` | Shows the current number of upcoming steps. |
| `/qt arrow` | Turns the waypoint arrow as the step's button on or off. |
| `/qt satellites` | Turns the small objective buttons around the arrow on or off. |
| `/qt badge` | Collapses two or more of those buttons into one +N badge that opens on hover. |
| `/qt status` | Prints the current state to chat. |
| `/qt welcome` | Opens the guide chooser. |
| `/qt restart` | Starts the current guide again from its first step. |
| `/qt why` | Opens "Why did guide skip?": the latest guide and step moves and what caused them. |

</details>
