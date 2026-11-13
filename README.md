# RXP ForeverTracker

A mouse-wheel scrollable quest tracker for WoW Forever (16001) with zone sorting (closest quest first), rewards after
quest titles and detailed quest tooltips, plus RestedXP guide steps in the tracker (click-to-use circles, waypoint
arrow, back-a-step button) when RestedXP Guides is installed. Blizzard's own tracker is kept and placed inside a
clipping frame that scrolls.

Optional: RestedXP Guides (guide steps), Questie (quest giver, turn-in, objective locations, chains, attunement star,
party progress, closest-quest sorting).

## Install / upgrade

1. Extract the `RXPForeverTracker` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
2. Upgrading from the earlier separate addons: log in once with them still enabled (settings are copied and this
   addon stays off for that session), then disable them and `/reload`.

## Settings: `/qt`

Categories on the left:

- **Quest Tracker**: Quest list (lock, extra length, scrollbar, items, quest count, header colours), Zone headers, Quest titles, Tooltips, Tracking and sorting (Track mode, zone sort).
- **RXP Tracker**: Tracker settings (including Own window), Waypoint arrow, Themes & guide (theme, status, choose a guide, restart or reset guides), Orphaned quests.
- **Settings Window**: Text and font, Advanced, Background, Profiles (save, load, delete, import and export; starts on "Default"), Minimap button.

Colours have presets, a custom colour and an opacity slider. The search box finds any setting.
Shift+right-click the guide in the tracker opens the window; right-click opens the guide menu.

## Commands

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
