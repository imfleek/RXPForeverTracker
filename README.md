# RXP ForeverTracker

A mouse-wheel scrollable quest tracker for WoW Forever (16001) with zone sorting (closest quest first), rewards after
quest titles and detailed quest tooltips, plus RestedXP guide steps in the tracker (click-to-use circles, waypoint
arrow, back-a-step button) when RestedXP Guides is installed. Blizzard's own tracker is kept and placed inside a
clipping frame that scrolls.

Optional: RestedXP Guides (guide steps), Questie (quest giver, turn-in, objective locations, chains, attunement star,
party progress, closest-quest sorting).

## Install / upgrade

1. Extract the `RXPForeverTracker` folder into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
2. Upgrading from the earlier separate addons: log in once with them still enabled (settings are copied and this
   addon stays off for that session), then disable them and `/reload`.

## Settings: `/qt` or `/qtrxp` (also `/rxpft`, the minimap button)

Categories on the left:

- **Quest Tracker**: Quest list (lock, extra length, scrollbar, items, quest count, header colours), Zone headers, Quest titles, Tooltips, Tracking and sorting (Track mode, zone sort).
- **RXP Tracker**: Tracker settings (including Own window), Waypoint arrow, Themes & guide (theme, status, choose a guide, restart or reset guides), Orphaned quests.
- **Settings Window**: Text and font, Advanced, Background, Profiles (save, load, delete, import and export; starts on "Default"), Minimap button.

Colours have presets, a custom colour and an opacity slider. The search box finds any setting.
Shift+right-click the guide in the tracker opens the window; right-click opens the guide menu.

## Commands

`/qt height <px>`, `/qt scale <0.5-1.5>`, `/qt step <px>`, `/qt zone`, `/qt sort`, `/qt lock`, `/qt unlock`,
`/qt reset` (scroll to top), `/qt on|off` (then /reload), `/qt debug`, `/qt guide`, `/qt orphan` (Orphaned quests). RXP Tracker commands, also typed after `/qt`: `toggle`, `0-100` or `all` (steps shown ahead), `arrow`, `satellites`, `badge`, `status`, `welcome`, `restart`, `why`.

## Layout

`Bootstrap.lua` (shared setup, migration), `Objectives/` (guide half),
`Tracker/` (tracker half), `Textures/`. Saved settings: `RXPForeverTrackerDB`, `RXPForeverTrackerGuideDB`.
