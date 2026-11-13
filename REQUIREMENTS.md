# RXP ForeverTracker requirements and status (formerly AllTrackerRXP)

## Targets

| Target | Interface | Source pin (Gethe/wow-ui-source) | Status |
|---|---|---|---|
| forever | 16001 | `forever` @ `eac30af597e5aaa43a60f6675ef5fdcea100375f`, version 1.60.1.70790 (plugin snapshot 2026-11-04) | primary; not yet run in the client |
| retail (Midnight) | 120105 | `live` @ `297d7aaaa736f346b3e036f38ee088eaf7f8c07f`, version 12.1.5.70783 | listed in the TOC; not yet run in the client |

Confirm the interface numbers with `select(4, GetBuildInfo())` in each client.

## Requirements

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| QTS-1 | The default Blizzard objective tracker scrolls with the mouse wheel; no custom tracker | Forever: user reported the wheel moved the list in 0.1.1 and `/qts debug` showed `offset=654` in 0.2.0; full list reachable not yet confirmed |
| QTS-2 | AllObjectives RXP's steps scroll together with the tracker | RXP module is re-parented into the clip frame; confirmed present in `/qts debug` ("foreign modules: 1") |
| QTS-3 | Settings window via `/qts config` and a minimap button | implemented; fake-API tests only |
| QTS-4 | Sliders: scale, visible height, scroll speed (layout room removed, automatic) | implemented; fake-API tests only |
| QTS-5 | Checkbox: sort all quests by zone, with zone headers | 0.3.0: watch-list re-sort + header labels; not run in client |
| QTS-8 | Only quests scroll; header and RXP guide fixed | 0.3.0: first module anchor offset under a clipped viewport; not run in client |
| QTS-9 | Scrollbar right of tracker | 0.3.0; not run in client |
| QTS-6 | Checkbox: lock / unlock tracker position | implemented (drag bar); fake-API tests only |
| QTS-7 | Nothing blocked or tainted in combat | 0.2.3: no frame moves, re-parenting or `EnableMouseWheel` calls in combat |

## Source evidence

- `SimpleScriptRegionAPI:EnableMouseWheel` is declared `IsProtectedFunction = true` with `SecretArguments = NotAllowed` on Forever (source-declared; addon access and runtime behaviour unverified). It is therefore called once, at creation, out of combat.
- Blizzard's own `Blizzard_ObjectiveTracker` source for the Forever pin could not be read from this session; layout behaviour (available height, truncation) is inferred from AllObjectives RXP's code and from `/qts debug` output.

- In-game `/qts debug` (0.2.2/0.2.3, Forever): 155 wheel events received, so the wheel reaches the addon. The tracker's top equalled the screen height (1052.05) regardless of the scroll offset, which indicates the tracker was clamped to the screen and pulled back each time it was moved. 0.2.4 turns clamping off (`SetClampedToScreen(false)`, out of combat) and re-applies it if Blizzard re-enables it. Not yet confirmed in the client.

## Open items

- Built-in Settings-menu registration (the plugin's baseline for addon options) is not done; the custom window was requested explicitly.
- Localization catalog not done (English only).
- Controller support for the settings window not assessed.
- Runtime testing route chosen by the user: Witchcraft in-game on WoW Forever. No Witchcraft tools are connected to this session, so the user runs the in-game steps and pastes `/qts debug` output.

## Settings window style (0.8.1)

- Reference: user-supplied ClassicUI Forever screenshot (gold dialog style) as the accepted design, plus the request to look native to Forever.
- Default style "Forever": `DialogBorderTranslucentTemplate` (shared dialog NineSlice, as in Forever's Edit Mode dialog) on a child frame, `GameFontHighlightLarge` title, `UIPanelButtonTemplate`, `UIPanelCloseButton`, `UICheckButtonTemplate`. "Window style" button switches to the classic gold `UI-DialogBox-*` border with title plaque. Each piece falls back to plain textures when its template is missing.
- Evidence: template names come from the plugin's Forever source map (pin 9dc84f0, reviewed 2026-11-08). Not run in a client; template availability in addon context, asset pixels and sizing are unverified. Sliders and the scroll bar are addon-drawn with stock textures (no native MinimalSlider/ScrollBox).
- Not done: controller/gamepad navigation of the window, localization catalog, Settings-menu registration.

## Settings window: native Forever look (0.8.1)

- Composition taken from the plugin's Forever native-art notes (source pin `9dc84f0d`, 1.60.1.70862, reviewed 2026-11-08): `DialogBorderTranslucentTemplate` shell as used by Forever's Edit Mode dialog, `GameFontHighlightLarge` title, `UIPanelCloseButton`, `UIPanelButtonTemplate`.
- Controls switched to native templates: `UICheckButtonTemplate`, `UISliderTemplate`, `SearchBoxTemplate`, `UIPanelScrollFrameTemplate`. Inherited scripts are hooked (`HookScript`), never replaced. Each is created through `pcall`; a missing template falls back to a plain composition.
- Not verified: that each template loads for addons on Forever, the pixels it renders, or controller focus/navigation. Needs a Witchcraft in-game check: open/close/reopen, resize, UI scale, hover/pressed/disabled/checked states, search, scrolling.
- Still open: localization catalog, built-in Settings-menu registration, controller support (focus order, back/close, scroll with a gamepad).

## Merge with AllObjectives RXP (2.0.0)

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| MRG-1 | AllObjectives RXP and AllTracker RXP ship as one addon (`AllTrackerRXP`), one install, Forever 16001 | done: one TOC, `Dependencies: RXPGuides`, AO's `AllowLoadGameType: camelot` and `LoadSavedVariablesFirst: 1` kept |
| MRG-2 | The two halves cannot overwrite each other's state | each half gets a private namespace (`root.objectives`, `root.tracker`); before, both wrote `ns.db`/`ns.say` |
| MRG-3 | Load order unchanged: guide code first, tracker after (tracker hooks run after the guide addon's) | TOC lists `Objectives/` before `Tracker/` |
| MRG-4 | A still-enabled separate AllObjectivesRXP does not draw the guide twice | `OptionalDeps` loads it first; `Bootstrap.lua` turns the built-in copy off and the tracker half uses the separate one; one chat notice |
| MRG-5 | Guide settings kept | copied once from `AllObjectivesRXPDB` into `AllTrackerRXPObjectivesDB` when both are loaded together; otherwise defaults |
| MRG-6 | Textures resolve from the merged folder | all paths built from the addon folder name |

Checks run: `texluac -p` on every file; stub-API load of the whole TOC in order, with and without the separate addon
(namespaces distinct, settings copied, no duplicate slash command). Not run in the client: Witchcraft in-game check of
guide + scrolling together, `/qt debug` line "AllObjectives RXP: built-in copy". No UI was changed, so the mock-up and
controller items above are unchanged.

## 2.1.0: rename, settings tabs, Auctionator, back a step

Choices: mock-up first (accepted: style B, design canvas "AllTracker RXP settings tabs mock-up"); testing route:
Witchcraft in-game (recorded earlier; no Witchcraft tools in this session, the user runs the in-game steps).
Auctionator source read: release 345 (2026-11-10), `Source/API/v1/GetAuctionPrice.lua`, loaded for every game type
including camelot through `Source/Manifest.xml`.

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R21-1 | Addon and branding renamed "RXP ForeverTracker" (folder, TOC, window title, chat prefix, minimap tooltip, frames) | done; old settings copied when the old addon is loaded in the same session (`Bootstrap.lua`); stub test: copied, addon stands down with a chat notice |
| R21-2 | /qt window: side icon tabs (style B), Quest Tracker = quest icon, AllObjectives RXP = Hearthstone icon | done: composed tabs (no verified Forever side-tab template), `Interface\GossipFrame\AvailableQuestIcon`, Hearthstone item 6948 icon (file 134414 fallback); stub test builds both tabs and switches; not run in client |
| R21-3 | AllObjectives RXP tab holds every /ao command and option | toggle, 0-8, quests, arrow, satellites, badge, lock, status (live box + print), welcome, reset; same state/calls as Slash.lua (`Objectives/Settings.lua`) |
| R21-4 | Quest Tracker hint: "/qt off then /reload restores Blizzard's tracker." | done |
| R21-5 | Guide hint: "Same as /ao in chat: toggle, 0-8, arrow, satellites, badge, quests, status." | done |
| R21-6 | Auction house value (Auctionator) in quest tooltips | reward and choice items show "(AH x)" after the vendor value; option under "Tooltips on quests"; link price first, item ID fallback, errors contained; not run in client |
| R21-7 | Back arrow left of the first skip-step box: go back one step | RXP-styled box with "<", `RXP.SetStep(GetGuideProgress() - 1)`, dimmed at step 1, tooltip; that line's use circles move left to make room; stub test: SetStep(4) from step 5, no call at step 1; verified against the user-supplied RestedXP source (GuideWindow.lua `addon.SetStep(n, n2, loopback)`, RXPGuides.lua `addon.GetGuideProgress`): the target skips sticky and above-level steps, which SetStep would forward past |

Controller: every new control is a native Button/CheckButton/Slider reachable by Forever's gamepad cursor. Not done:
shoulder buttons to switch tabs and a Back binding to close (Forever's SmartNavigation entry points and
`EnableGamePadButton`, declared protected, are unverified for addons), focus highlight on the back box. Not run with a
controller.
In-game checks needed: window on both tabs (icons, gold edge, tooltips, resize, text size), every guide option against
`/ao status`, AH value with and without Auctionator, back box position with and without use circles on the first line,
first-login migration message.
Localization: English only (unchanged).

## 2.2.0: change guide from a right-click

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R22-1 | Right-click on the guide in the tracker changes the selected guide; never an empty list or the importer | `Objectives/features/GuideMenu.lua`: RestedXP's own guide part of `RXPFrame:GenerateMenuTable` (as `ShowGuideSelectionMenu`), or, when it holds no guide (IsGuideActive filtering, hidden "*" groups), every guide `LoadGuide` accepts; loads with RestedXP's own click logic (`guide.OnClick` or `LoadGuide`); source: user-supplied RXPGuides (GuideWindow.lua, GuideLoader.lua, UI/V2/Core.lua). Stub test: both cases, farm/internal excluded, no import entry. Not run in client |
| R22-2 | Header Browse Guides button and welcome screen use the same menu | done; the small indicator keeps "Click: browse guides. Right-click: settings." |

## 2.2.1: no AH values without Auctionator

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R221-1 | Without Auctionator, quest tooltips show no AH value and nothing calls into it | `Tracker/Extras.lua` auctionatorAPI(): needs `C_AddOns.IsAddOnLoaded("Auctionator")` and its v1 price functions; the option is not listed in the window without it. Stub test: absent -> no lookups, no option, window builds; present -> link price x count, ID fallback. Not run in client |

## 2.2.2: tracker off screen

User report (/qt debug, 2.2.1): window top -884 with the screen 0..1052, fitCap=100, change log "window.top 815.5 > -884.2"
in frame 2, no saved position. Cause: Blizzard anchors the tracker to a frame whose position depends on the tracker's
height; the tracker is EXTRA (3000) px taller here, which moved that frame, and the window with it, by about half of that.

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R222-1 | The tracker window stays on screen with no saved position | `capture()` turns an anchor to anything but UIParent into a fixed screen position read at Blizzard's own height, and ignores it once the tracker is taller; simulation (fake container that drops by half the tracker height, real Core.lua): previous code top -400, fixed top 812 |
| R222-2 | A window that still ends up off screen (old saved spot, other resolution) comes back | layoutGhost safety net: top right below the minimap, saved spot cleared, one chat line; simulation with an off-screen saved spot: top 812 |
| R222-3 | /qt debug shows Blizzard's anchor | "Blizzard anchor: <point> to <frame> ..." line |

Trade-off: while Blizzard anchors the tracker to such a frame, an Edit Mode move of the tracker is not followed after
login (the window keeps the spot read at login); /qt unlock and drag, or /reload after Edit Mode.

## 2.2.3: no message spam after /reload

User report (2.2.2): the "moved back to the top right" line repeated for ~10 s after /reload, then stopped.
Cause: the off-screen check ran inside every layout pass, while positions during and right after the loading screen
are not final.

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R223-1 | No repeated off-screen messages; no reset caused by load-time positions | check starts 5 s after setup, runs on a 1.5 s timer, needs two off-screen readings in a row, prints at most once per session; simulation over 20 s: load-time glitch (off screen for 3 s) -> 0 messages, on screen; saved spot below the screen -> 1 message, on screen |

## 2.2.4: guide tab wording

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R224-1 | No command lines under the options of the guide tab | grey sub-lines removed (incl. the Ctrl+Right-click hint under "Lock the arrow"), "(/ao 0-8)" dropped from the slider label; the footer hint is unchanged |
| R224-2 | Guide tab named "RestedXP Tracker" | tab tooltip and the section shown when the guide half is inactive |

## 2.2.5: guide menu beside the tracker

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R225-1 | The right-click guide menu does not cover the steps | the menu opens beside the right-clicked guide section, on the side with more room (left of the tracker when it is on the right half of the screen), through the dropdown frame's point/relativePoint/relativeTo fields read by LibUIDropDownMenu/UIDropDownMenu ToggleDropDownMenu (RXPGuides libs/mainline); own dropdown frame, RestedXP's menus unchanged; while it is open, guide submenus open left of their parent too (post-hook on ToggleDropDownMenu, Blizzard's and LibUIDropDownMenu-4.0's). Welcome screen "Browse Guides" stays at the cursor. Stub test: right/left placement, cursor case, submenu re-anchored left. Not run in client |

## 2.2.6

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R226-1 | Login message points to /qt or /qtrxp instead of /aorxp; /qtrxp opens the settings | done (`/ao`, `/aorxp` still work) |
| R226-2 | "Settings window" section first on the Quest Tracker tab | done |
| R226-3 | No duplicated xp/gold on quest titles when hovering other quests | user screenshot: "390xp" repeated ~22x. Blizzard re-sets a title with its decorated text; captured titles are now cleaned of our suffix ("  |c...") and marker indent, and our own text set again is ignored; string test incl. the 22x case, xp orb, coins, marker. Not run in client |

## 2.2.7: duplicate xp, second fix

User video (2.2.6): hovering quests in the world map's quest list still added one "390xp" per hover to the tracked
quest's title. The 2.2.6 cleanup cut at the first "  |c", which that path's text did not match.

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R227-1 | A title never shows its rewards more than once | baseTitle removes every form render() appends (xp, xp orb, gold letters/coins, rep; any spacing; coloured or with colour codes removed) until nothing changes, and render() cleans the stored title before every decoration, so output is always title + one suffix; string test: 22x, single/no space, colour-wrapped, codes removed, xp+gold repeated, orb+coins, marker indent, a title with a number kept. Not run in client |

## 2.3.0: RestedXP Tracker and Quest Tracker scales

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R230-1 | Separate scale sliders for the RestedXP Tracker (guide) and the Quest Tracker | "Size and layering", under General scale, 50-150 %, saved as guideScale/questScale (default 100 %) |
| R230-2 | No conflict between them or with the general scale | both multiply the general scale (which scales the whole tracker frame): quest modules = questScale as children of the tracker; the guide module = tracker scale x guideScale (Tracker.lua place(), which previously forced it back to the tracker scale on every layout). Each module's width is divided by its own factor, so on screen it is exactly as wide as the window; scrolling already converts with each module's effective scale. The old login step that reset these two scales to 1 is removed. Simulation: general 0.8 x quest 1.25 -> module 208 px on screen = tracker 208 px; guide 0.8 x 0.9 with width 260/0.9 -> 208 px |
| R230-3 | Safe in combat | module scales are applied out of combat only and again when combat ends; the guide width only when the module is not protected |
Not run in client: visual check at several combinations, scrolling to the end of a scaled list, pinned guide height at guide scales above 100 %.

## 2.3.1: divider under the last step

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R231-1 | A divider line stays between the last shown step and the "Quests" header | gold line (UI-World-Quest-golden-line, colour fallback) in a 12 px gap, anchored to the window, so it does not scroll; shown while the guide is fixed on top |
| R231-2 | Scrolling quests never cover the last step | the clip edge is measured from the lowest shown point of the guide's rows, lines and use circles (not the module frame, which the last step overhangs), minus the gap; the first scrolling section is pushed down by the same amount at every scroll position (hook, refresh, setOffset), so scroll range and scrollbar stay consistent. Simulation: frame bottom 662, last step 657, divider 653-649, clip edge 645 |
Not covered: while a Blizzard section (e.g. a scenario) sits above the guide, the guide is not fixed and scrolls with the quests, as before; no divider then.

## 2.4.0: all quests, beyond the game's watch limit

User report: 31 quests in the log with "Track all quests", only 20 reachable by scrolling; wants all of them (up to 40).
Cause: the game caps watched quests (Constants.QuestWatchConsts.MAX_QUEST_WATCHES; 20 on Forever by this report) and
Blizzard's tracker draws only watched quests. No addon can watch more.

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R240-1 | Every quest in the log is listed with "Track all quests" | `Tracker/MoreQuests.lua`: a "More quests (the game tracks N)" section under Blizzard's quests lists the unwatched ones (title with level in difficulty colour, objectives, "Ready for turn-in", zone headers when sorting by zone), anchored below the lowest Blizzard section so it scrolls with the list; Core's scroll range includes it; quest scale and width follow; click opens the quest log, Shift-click tracks when there is room. Hidden quests, tasks and the zone filter's hidden quests are left out. Option "Also list quests beyond the game's tracking limit" (on). Stub test: 31 in log, 20 watched -> 11 listed, bottom in the scroll range |
Not in that section: the xp/gold after titles and the quest tooltips (those hook Blizzard's quest blocks). Not run in client.

## 2.4.1: More quests placed after the last quest

User video (2.4.0): "More quests (the game tracks 25)" was drawn over the middle of Blizzard's list. Blizzard's quest
section frame ends above its last quests; the section, and the scroll range, used that frame edge.

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R241-1 | "More quests" is readable and part of the scrolled list | anchored to the section's top, offset down to the lowest shown quest entry (blocks/lines) + 8 px, re-measured every layout pass; stub test: section top 800, last quest 150 -> offset -658 |
| R241-2 | Scrolling reaches the last quest | Core's scroll range uses the lowest shown entry of each section (moduleContentBottom) instead of the section frame's edge; this also explains the earlier "only 20 of 31": the watch limit on Forever is 25 (video), the rest was cut off by the scroll range |

## 2.5.0

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R250-1 | Quest tooltips on the "More quests" section too | the tooltip is built from a quest ID (api.showQuestTooltip: overview, objectives, rewards with vendor/AH value, party progress) and used by both Blizzard's quest blocks and More quests, which adds its "not tracked" lines at the end |
| R250-2 | Tooltip sub-option: coin icons instead of g, s, c | "Coin icons instead of g, s, c" under "Tooltips on quests" (db.tooltipCoins, off); applies to the Gold line and vendor/AH values; the titles keep their own "Show coins instead" |
| R250-3 | Sorting by zone puts the closest zone first | ZoneSort: header names matched to map IDs from the map tree; world centre per zone (dungeons: parent zone); player's world position; order = own zone, same continent by distance, other continents, unknown; re-sorts on ZONE_CHANGED_NEW_AREA; More quests uses the same order. Fake-map test: Tanaris, Zul'Farrak, Desolace, Badlands, Riverglades. /qt debug shows your zone and continent. Not run in client |

## 2.5.1

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R251-1 | Shift+right-click on the RXP tracker opens the /qt window | opens on the RestedXP Tracker tab; again closes it; plain right-click still opens the guide menu. Not run in client |

## 2.5.2: Reset position loop

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R252-1 | "Reset position" puts the window back once and it stays | reset (and Reset to defaults) now saves a fixed position: the tracker's top left as read at login before it is changed (when on screen), else the default spot below the minimap; it no longer switches to following Blizzard's anchor live, the path that looped (user report). Simulation: saved spot, then Reset, 20 s: window top constant, no off-screen messages. Not run in client |

## 2.5.3: default position in the middle of the screen

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R253-1 | First use places the tracker in the middle of the screen | no saved position at login -> saved as CENTER of the screen; Reset position, Reset to defaults and the off-screen safety net use the same spot; a dragged position is kept. Simulation (1052 px screen, 500 px window): top 776 on first use, after Reset (stable 20 s) and after an off-screen spot |

## 2.6.0

Implemented directly from the user's itemised list (no mock-up round: each item named its place and behaviour).

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R260-1 | "More quests" heading removed; the list blends into the quest tracker | Blizzard's fonts, header/dash/text offsets, colours (OBJECTIVE_TRACKER_COLOR) and spacing (fromBlockOffsetY, lineSpacing) sampled from a shown quest block; ZoneSort's zone label style and room; continues from the last tracked zone; stub test |
| R260-2 | xp/gold after More quests titles | shared api.rewardSuffix (Extras.lua), same settings and order as tracked titles |
| R260-3 | Tooltip sub-option: experience orb icon, no space before it | db.tooltipXpOrb; orb texture with no offset right after the number |
| R260-4 | No space behind coin icons in tooltips | tooltip coins joined without spaces |
| R260-5 | "Step X of Y" beside the guide name, right | on the guide title's line, left of the collapse button; the old centred counter removed |
| R260-6 | Quest log count left of the Quests collapse button, coloured | n/max (GetNumQuestLogEntries quests, GetMaxNumQuestsCanAccept or 40); green <=26, yellow 27-36, orange 37-39, red 40 (scaled to max) |
| R260-7 | Scrollbar colour picker under "Show scrollbar" | db.scrollbarColor applied to the thumb |
| R260-8 | "Quest list: only this guide's turn-ins" removed entirely | settings window, footer hint, /ao quests and its help line removed; switched off at login if it was on |
| R260-9 | Zone sort dropdown: alphabetical or closest | "Sort zones (with zone headers)" under the zone-header modes; db.zoneOrder; More quests follows |
| R260-10 | Prompt 8 s after loading when a custom quest tracker is detected | Conflicts.lua: Kaliel's Tracker, BetterQuestList, SorhaQuestLog, QuestGuru_Tracker, Questie (tracker on); disable this addon / the other (reload) / keep both (remembered); Escape does nothing; stub test |
| R260-11 | "Show minimap button" under "Settings window" | moved |
| R260-12 | Font dropdown under "Settings window" for quest tracker, RestedXP Tracker and GUI | Fonts.lua: game default, Friz Quadrata, Arial Narrow, Morpheus, Skurri, LibSharedMedia fonts; Blizzard tracker font objects (size/outline kept, restored for default), guide via ns.textStyle, zone headers, settings window; stub test |
| R260-13 | Y-axis padding slider for the Quests header under the last step | 0-40 px added below the divider; scroll clip and quest list follow |
| R260-14 | Guide tab icon: classic RestedXP logo | RXPGuides\Textures\rxp_logo-64 |
Controller: the new dropdown is a native button with a list of buttons, reachable by Forever's gamepad cursor; not run
with a controller. Nothing above run in the client yet.

## 2.6.1

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R261-1 | No Lua error from the quest count at login | user error: MoreQuests.lua:387 SetFont size nil; `(a and b:GetFont())` kept only the font file. The three values are now read without parentheses, with the game font as fallback; test with BigWigs' NotoSans on the header: no error, colours green/yellow/orange/red at 26/27-36/37-39/40 |

## 2.6.2

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R262-1 | The font dropdown changes the quest tracker's quests too | user report: only the Quests header, zone headers and guide changed (Forever's quest titles/objectives do not use the ObjectiveTracker font objects). The chosen font is now set on the tracker's own text (section headers, titles, objective lines, dashes) after every tracker update, originals remembered for "Game default", relayout at most once a second; stub test: Arial applied, re-applied after Blizzard resets a title, default restores Friz with size/outline kept |

## 2.6.3

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R263-1 | "Quests" header Y-axis padding goes down to -50 px | slider -50 to +40; negative values pull the quest list up (the push-down may now be negative); the divider hides once there is no room for it. Simulation (last step bottom 657): +20 -> quests 625, divider 653; 0 -> 645; -30 -> 675, divider hidden; -50 -> 695 |

## 2.6.4

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R264-1 | Coins in tooltips: "40(s) 43(c)": no gap after the number, one space after each coin, none after the last | the text had no spaces there; the gaps were the coin images' empty border, now cropped (texcoords 2..14 of 16, both axes); coins joined by one space. Text check: "(vendor 40[Silver] 43[Copper])"; title cleanup still removes coin rewards. Crop amount not checked in client |

## 2.7.0: Questie integration

Source read: Questie 12.7.0 with QuestieDB (user-supplied; Questie_Forever.toc, Interface 16001). Data through the
global LibQuestieDB (QuestieDB/src/api.lua), Quest/Npc/Object/Item .Get(id, field), field names from QuestieDB/Types;
readiness from Questie.API.isReady / RegisterOnReady (Questie/Public).

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R270-1 | Questie data only while Questie is used, behind a checkbox | "Use Questie data (...)" listed only when Questie and LibQuestieDB are loaded; used only when Questie.API.isReady and the option is on (default on) |
| R270-2 | Quest giver and turn-in in tooltips | name (zone x, y) from startedBy/finishedBy NPC or object spawns (zone with most spawns), item starters by name |
| R270-3 | Objective locations in tooltips | creature/object objectives by spawn zones, item objectives by the zones of what drops them (npcDrops/objectDrops), up to 3 zones |
| R270-4 | Quest chain in tooltips | position and length from preQuestSingle/preQuestGroup back and nextQuestInChain forward (cycle-safe, 25 max), previous and next quest names |
| R270-5 | Better closest-zone sort | zone = objectives' zone, the turn-in's zone once complete, else Questie's zoneOrSort (C_Map.GetAreaInfo names); used for sorting, zone headers and More quests; re-sorted when Questie becomes ready or the option changes |
Fake-database test: giver "Marin Noggenfogger (Tanaris 51.6, 26.9)", turn-in Krazek (Stranglethorn Vale), objectives
Zul'Farrak/Tanaris and the item's dropper zone, chain 3 of 4 with previous/next; zone Zul'Farrak in progress,
Stranglethorn Vale once complete; nothing when not ready or off. Not run in client.

## 2.8.0: Questie chains in tooltips

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R280-1 | Tooltip sub-checkbox: follow-up quest / chain from Questie | "Follow-up quest and chain (Questie)" under Tooltips (listed with Questie only, default on): "Follow-up: <next>", "Chain: quest X of N" |
| R280-2 | Whole chain while Ctrl is held | numbered list, current marked, completed greyed (IsQuestFlaggedCompleted), quest levels; the open tooltip is redrawn on MODIFIER_STATE_CHANGED (Ctrl) |
| R280-3 | Checkbox: the chain's final reward (items, gold) | "Chain's final reward and total experience and gold" (default on): final quest's reward items from Questie's Item.questRewards (reverse index built 1500 items per frame, "loading..." meanwhile, tooltip redrawn when ready) and its gold (GetQuestLogRewardMoney) |
| R280-4 | Combined gold and experience for completing the chain | sum from this quest to the end: experience from Questie's QuestXP (level-adjusted), gold from GetQuestLogRewardMoney (0 where the game has no data for a quest yet) |
Fake-database test: follow-up, chain 3 of 4, Ctrl list, final reward item after the index builds, total 7400 xp 1g 65s.
Not run in client.

## 2.8.1

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R281-1 | "Chain total" only while Ctrl is held | shown with the whole chain under Ctrl; the hint says so; the final reward stays visible; fake-database test |

## 2.9.0

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R290-1 | Star in front of raid attunement quests (sub-checkbox of Elite+ icons, Questie data) | Questie.lua: attunement completions by ID as Questie's files name them (7848, 6502, 6602, 7761, 10888, 13430, 10901, 11052) plus Karazhan/Naxxramas/Hyjal by name (Quest.IdsByName after BuildNameIndexAsync, a coroutine resumed once per frame; English names only); a quest counts when it or its chain forward (nextQuestInChain, childQuests, 300 quests max) reaches one; star (UI-RaidTargetingIcon_1) after the Elite+ indent, also on More quests; title cleanup removes it. Test: chain to 7848 yes, unrelated no, name-resolved follow-up yes after the index builds, cleanup |
| R290-2 | Settings window: no words cut off | buttons widen to their label at any text size/font; dropdown label wraps and its button grows; dropdown rows size to their text (checkboxes, sliders, colours, sections already wrapped) |
| R290-3 | Shift+right-click on the RestedXP tracker opens the Quest Tracker tab | openConfigTab("quests"); again closes it |
Not covered: Blackwing Lair's other chain, Naxxramas/Karazhan/Hyjal on non-English clients, raids whose attunement Questie neither labels nor names as above. Not run in client.

## 2.9.1

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R291-1 | "Chain ends with" only while Ctrl is held | the final reward and chain total show with the whole chain under Ctrl; the reward-item index starts building when the chain tooltip first shows, so it is ready for Ctrl; fake-database test |
| R291-2 | Smoother settings-window scrolling | wheel notches move a target (60 px x text size) and the view eases towards it (rate 14/s, about 0.4 s for two notches at 60 fps), notches add up; scrollbar drag and tab switches cancel the glide; native and fallback scroll frames |
The request's cut-off third line was dropped at the user's instruction.

## 2.9.2

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R292-1 | The closest quest/objective is at the very top of the quest tracker | user report: closest-zone sort not working (it compared zone centres only, and the game's own C_QuestLog.SortQuestWatches could undo it). Per-quest distance now: Questie on → nearest spawn of the quest's objectives (creatures, objects, item droppers, kill credit; turn-in once complete) via Questie ZoneDB area→map and C_Map.GetWorldPosFromMapPos; else C_QuestLog.GetDistanceSqToQuest; else GetNextWaypoint; else zone centre. Zones ordered by their closest quest, quests within a zone closest first (30-yard steps so near ties do not flip). Re-checked every 4 s and after the game's SortQuestWatches; out of combat; max 4 re-orders/10 s; detects a client that adds watches at the front. "Alphabetical" keeps A-Z zones, closest first inside. More quests uses the same order. `/qt debug` lists each tracked quest's distance and source. Stub test prox_test.lua (normal and front-insert clients, Blizzard re-sort, movement, tiny moves ignored); in-game: not run |

## 2.9.3

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R293-1 | One "Star on raid attunement quests" checkbox | two copies (attuneStar and attunementStar, each read by a different file) merged into db.attunementStar; an earlier "off" carries over; one star implementation (Extras.lua, Elite+ icon size) |
| R293-2 | "Size and layering" renamed "Advanced sizing" | Config.lua section title |
| R293-3 | No error turning on More quests | user report MoreQuests.lua:334 concatenate nil: a leftover line added the star a second time, and Questie.lua's copy of the star function returned nil for non-attunement quests. Line removed, the star function always returns a string; stub tests (more_test, attune_test) |

## 2.9.4

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R294-1 | "Icon size" scales only the icons on quest titles, never the layout | Elite+ markers (skull, dungeon, raid, PvP) and the attunement star are no longer inline |T/|A text (which grew the line and pushed the title). Each is a texture centred on a fixed 14 px slot in front of the title; the title is indented by the slots' width at 100 %, so text, line height and the quests below stay put at 50-250 %. Same in More quests. Also removed a second star being added to tracked attunement titles. Stub test icon_test.lua: same indent at 50/100/250 %, icon size and centre per slot, icons hidden when none; in-game: not run |

## 3.0.0

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R300-1 | /qt window redesigned as mock-up Option A (after WoW Forever's Options window) | design canvas https://claude.ai/artifact/LHyRmFEoRHNAvPFcviwaDW. Title bar with gold name and Forever's red close button; left category list with gold group headers (Quest Tracker with the quest icon, RestedXP Tracker with the RestedXP logo, Settings window) and gold page names, open page highlighted; search box above a dark page panel; page title with a red "Defaults" button (resets the page's group: quest settings or guide settings); label-left / control-right rows; bottom bar with version, hint and red "Close"; resizable 720x480 to 1400x1100, default 880x660 (older smaller saved sizes ignored). Pages: Quest list, Zone headers, Quest titles, Tooltips / Guide in the tracker, Waypoint arrow, Guide / Text and font, Advanced sizing, Minimap button (the user's sidebar edit on the canvas). Search lists matches from every page under the page's name |
| R300-2 | Option B's on/off switches | every checkbox is a gold/dark pill switch with a knob; clicking the label toggles too; option sounds |
| R300-3 | Option B's colour swatches plus a custom colour | five presets (green, gold, blue, purple, white) and a custom button opening the game's colour picker; a ring marks the current colour, a non-preset colour shows in the custom button; scrollbar, zone header and experience colours |
| R300-4 | "Only quests in my zone" is a choice of "Track" | Track picker: Game default, All quests, All quests with zone headers, Only quests in my zone, Manually tracked, Manually tracked with zone headers (< > arrows step, the value opens the list). Stub test track_pick_test.lua: every choice sets and reads back; leaving "my zone" clears the filter |
| R300-5 | Pickers and sliders from Option A | < value > pickers with a list; sliders with a thin track, diamond thumb, step arrows, typed value, mouse wheel steps |
| Checks | smoke2 (all modes) builds the window and opens /qt guide and /qt quests; in-game visual comparison with the mock-up and controller navigation: not run (needs the Forever client) |

## 3.0.1

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R301-1 | RXPGuides is no longer a required dependency | TOC: Dependencies line and "Group: RXPGuides" removed; RXPGuides moved to OptionalDeps (still loads first when installed). Without it the guide half stays off (existing rxpAvailable check, every Objectives file returns without ns.rxp) and the RestedXP Tracker page says RestedXP Guides is not available; smoke2 loads and builds the window with no RXPGuides |
| R301-2 | Auctionator prices removed from tooltips | Extras.lua price lookup, the "(AH ...)" text, the setting, its default and the Auctionator optional dependency removed; the saved ahValue key is cleared on login. Supersedes R-Auctionator items from 2.x |
| R301-3 | "(guide: /ao)" removed from the addon list description | TOC Notes now ends "Settings: /qt" and no longer mentions Auctionator |

## 3.0.2

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R302-1 | Cogwheel icon beside the Settings Window header; "Window" capitalized | group header icon Interface\Buttons\UI-OptionsButton (the game's gear), same slot as the quest and RestedXP icons; in-game look: not run |

## 3.0.3

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R303-1 | "RestedXP Tracker" renamed "RXP Tracker" in the settings window | category header, "RXP Tracker scale", the font note |

## 3.0.4

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R304-1 | No scrollbar in /qt on a page with nothing to scroll | layout hides the bar when the range is 0; the template's own re-show is undone (scrollBarHideable + OnShow check) |
| R304-2 | The quest tooltip does not resize when Ctrl shows the chain | on Ctrl the tooltip is redrawn in place (no SetOwner: no hide/re-place) and keeps at least its current width (SetMinimumWidth); only the lines change |
| R304-3 | No transparent black outline around /qt | the outer shadow texture removed |
| R304-4 | Party members' progress instead of "on quest" | counts from this addon's party messages, else from Questie's party sync (QuestieComms.remoteQuestLogs, "Name" or "Name-Realm"): "7/12", "done (12/12)"; "on quest (no progress shared)" only when neither shares counts. Stub test party_test.lua |
| R304-5 | Transparency on every colour picker | every colour row has an Opacity slider (5-100 %) under the swatches; picking another swatch or a custom colour keeps the opacity; saved as the colour's 4th value. Scrollbar (default 85 %), zone headers (text alpha), experience (alpha byte of the |c code: the game may ignore text colour alpha, not verified in-game), background |
| R304-6 | Settings Window > Background | new page: Show a background behind the trackers, Background colour (with opacity, default black 40 %), Space around the trackers (0-30 px). One texture behind the RXP Tracker and quest list (below their frame level), from the window top to the last quest shown or the window bottom |
| R304-7 | Questie integration future-proof | no quest/NPC/zone lists of our own for tooltip data; database = LibQuestieDB or, without it, Questie's QuestieDB module (Query*Single, ItemPointers); zone names from the game or Questie's TrackerUtils; ready = Questie.API.isReady or (no such API) data answering; per-quest caches cleared when Questie reports ready. Stub test questie_test.lua gives identical output through LibQuestieDB and through the QuestieDB module. The attunement star still uses known final quests plus names containing "Attunement" (Questie has no attunement tag) |
| Note | "More Quests" report withdrawn by the user; the 3.0.4 attempt at it was reverted | ZoneFilter/Track/MoreQuests as in 3.0.3 |

## 3.0.5 (performance pass, separate zip)

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R305-1 | Less CPU | /qt debug's layout change log no longer runs every frame (it built a table and formatted strings each frame); it records for 60 s after /qt debug. The content scan (every block, three times per layout: scroll range, scrollbar, background) runs once per frame. Closest-quest re-sort checks only after 20+ yards of movement (or every 30 s). "Track all" stops at once when the watch list is full (most quest updates). Space widths for title icons measured once per font |
| R305-2 | Less memory | the attunement check no longer builds Questie's whole-database quest name index; attunement names are compared while walking a quest's chain. Duplicate attunement code (two implementations, one overriding the other) merged into one |
| R305-3 | Leftover bloat removed | unused api.zoneDistance, api.questDistance, api.attunementStar (text form), api.resetIcons; README rewritten (no Auctionator, no "requires RestedXP", current window layout); REQUIREMENTS.md kept in the project but left out of the distributed zip |
| Checks | all stub tests pass on the optimized copy (smoke2 in three modes, 18 feature tests, questie_test through LibQuestieDB and the QuestieDB module); no new globals. In-game CPU/memory measurements: not run (needs the Forever client: /run UpdateAddOnCPUUsage() with scriptProfile, or the addon memory list) |

## 3.0.6

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R306-1 | Quest tooltip does not grow on each Ctrl press/release | bug in 3.0.4: each redraw set the minimum width to the frame's width, and the frame adds its padding on top, so it grew every time. Now both forms (Ctrl held and not) are measured when the tooltip opens; every redraw sets that one width (content minimum corrected once by the measured frame width). Width lock cleared when the tooltip hides, so other tooltips are unaffected. Stub tests tipwidth_test (padding 20 and 28): same width on open and over three Ctrl down/up cycles; in-game: not run |

## 3.0.7

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R307-1 | Background leaves the usable quest items out and starts just left of the zone titles | left edge = leftmost shown zone header minus "Space around", never further left than the window's left edge (the item buttons sit left of it); without zone headers the window's left edge. Redrawn after the headers are placed. In-game: not run |

## 3.0.8 (second optimization pass)

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R308-1 | More quests list: no redraw when nothing shown changed | the section is first described as data (titles, rewards, objectives, fonts, offsets, width) and compared with the last drawing; quest log updates that change nothing there (most of them) leave every row alone. Settings and other modules force a redraw (api.rebuildMoreQuests); zone header style changes now redraw it too. more_test: 0 SetText calls on an unchanged update |
| R308-2 | Quest titles: no SetText when the decorated title is unchanged | Extras render compares with the current text, so a tracker update that changes nothing does not make the game measure the titles again |
| R308-3 | Party progress sent only when it changed | was sent every few seconds on quest log updates while grouped; now only when the encoded progress differs, plus a full send when the party changes or after a loading screen |
| R308-4 | Font re-apply once per frame | Fonts.lua queued a timer on every tracker update (several per frame); now one per frame, and none with the game's own font |
| Checks | all 19 stub tests and smoke2 (3 modes) pass; no new globals; in-game CPU/memory: not run |

## 3.0.9

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R309-1 | "Space around the trackers" extends the background on every side, also left and down | left edge = 2 px before the zone headers (or the window's edge) minus the space, no longer held at the window's edge; bottom = end of the list (or the window's bottom) minus the space; top and right plus the space. Stub test bg_test.lua (0, 6, 20 px) |

## 3.0.10

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3010-1 | Changelog covering every version, kept up to date | CHANGELOG.md (shipped in the zip), built from this record; every new version adds its entry before packaging |

## 3.1.0: Forever Style theme

Reference: user screenshot (guide "46-47 Feralas/Azshara", Step 73-76 under "Upcoming Steps"), taken as the accepted
design; implemented directly. Testing route: Witchcraft in-game (user).

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R310-1 | Theme dropdown under Guide in /qt: "RXP Style" (original, default) and "Forever Style" | Config.lua Guide page "Theme" picker; saved as RXPForeverTrackerGuideDB.theme; reset with the guide defaults |
| R310-2 | Forever Style header blends with the game's tracker | the guide module's own Blizzard header (Text, background, collapse button) shows the guide name; RXP logo, class badge, subtitle and "Step X of Y" hidden; buttons ! (browse guides), ? (left /qt Guide page, right RestedXP settings), < back a step, > next step (spellbook page arrows, disabled at the ends); the container header's cog/logo buttons hidden |
| R310-3 | Steps drawn like quests | "Step N" (plus " - title" when RestedXP gives one) as the block header in the header colour; no number lane; upcoming steps at full size and normal colour; first line without dash, later lines with the game's dash; no skip boxes or back box |
| R310-4 | "Upcoming Steps" section header | a copy of the module header's textures, font and collapse button art under the last current step; collapse folds the upcoming steps (db.upcomingCollapsed), expand art used when the client has an "expand" atlas |
| R310-5 | Info icon on upcoming steps | FriendsFrame InformationIcon after the heading; tooltip; click = SetStep(n) |
| Checks | forever_test.lua (both themes, folded header, i click, < > limits); all earlier stub tests and smoke2 pass; no new globals. In-game: not run (header art copy, button art sizes, folded height, scroll range, Fonts.lua on the new header) |
| Controller | new buttons are native Buttons reachable by Forever's gamepad cursor; not run with a controller |

## 3.1.1

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R311-1 | No Lua error when Forever Style is turned on | user report: 636x "CreateTexture(): Couldn't find inherited node "0"" (Rows.lua:293): GetDrawLayer's sublevel was passed as CreateTexture's template argument. Now CreateTexture(nil, layer, nil, sublevel). The header is built once in a pcall; a failure is reported once and the divider line is used. forever_test.lua stub now rejects a template argument as the client does, and checks one error over 5 layouts |

## 3.1.2

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R312-1 | "Upcoming Steps" header above the first upcoming step's heading | user report: overlap. The gap was the first line's spacing inside the upcoming block (below its "Step N" header). Now the last current step's height grows by the header and the header is anchored under its last line; the upcoming block follows. Folded: same growth, no bottomSpacing change. forever_test: row height 20 -> 53, no gap in the upcoming block |
| R312-2 | The i opens the step's quest in the quest log, else sets a waypoint | step = guide.steps[n]; quest = element.questId of complete/turnin/accept elements that is in the log (that order); open with QuestMapFrame_OpenToQuestDetails (classic QuestLog_SetSelection fallback); else first element with zone (uiMapID) and x/y (0-100) or zx/zy -> C_Map.SetUserWaypoint + C_SuperTrack.SetSuperTrackedUserWaypoint, chat line with zone and coordinates; map that cannot be pinned -> coordinates in chat. Shift-click: go to the step. Tooltip says what a click does. Fields from RXPGuides functions.lua (goto/waypoint parsing, its own SetUserWaypoint use). forever_test covers all three; in-game: not run |

## 3.2.0

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R320-1 | Forever Style header shows the guide's sub-selected name, not its group | RestedXP's snapshot: title = guide.subgroup ("Dungeon Guide"), subtitle = guide name when grouped (UI/V2/Core.lua BuildGuideStepsSnapshot); header uses subtitle when set |
| R320-2 | Step action buttons movable only while Ctrl is held: Ctrl+left-drag moves, Ctrl+right-drag resizes (user's follow-up message) | Action.lua: one saved offset (db.circleOffset) and size factor (db.circleScale, 0.5-3, drag up = larger) applied to every step button, so they still follow the steps when scrolling; "ctrl-type*" = "noop" so a Ctrl-click runs no secure action; Ctrl skips the destroy/abandon confirm; out of combat only (secure buttons); "Reset step buttons" in /qt Guide in the tracker. Arrow buttons unchanged. In-game: not run |
| R320-3 | Ctrl+right-click on the RXP Tracker opens a window in the /qt style listing quests that cannot be done for missing prerequisites, with steps to do those | Tracker/Prereqs.lua with Config.lua api.themeKit (same colours, edge, title bar, panel, red buttons; movable, resizable, Esc). Quests = the guide's accept steps from the current step on, not done and not in the log; blocked when a direct prerequisite (Questie preQuestSingle: one of; preQuestGroup: all) is not done and no guide step between now and that step accepts or turns it in. Plan per quest (Questie.lua api.prereqPlan): prerequisites of prerequisites first (depth 12, 30 quests), each with Accept (giver NPC/object/item, zone and coordinates, level needed), objectives (Do: label: zones), Turn in; "in your quest log", "the guide does it at step N", "or one of N other quests" notes; click a pinned step for a waypoint. Without Questie: a message. prereq_test.lua; in-game: not run |

## 3.2.1

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R321-1 | The prerequisites window is called "Prerequisite Journal" | window title, /qt note, comments, changelog |
| R321-2 | A journal icon left of the guide title opens it | Header.lua: INV_Misc_Book_09 button (16 px, highlight, tooltip); RXP Style after the logo with the guide name moved right by the icon; Forever Style at the header text's template position with the name after it; click = api.togglePrereqs. header_test.lua (both styles, subtitle/title choice, click). In-game: not run |

## 3.2.2

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R322-1 | Journal steps say the action instead of "Do:" | Questie.lua objectiveSteps from Questie objectives: creatures/kill credit -> Kill (zones), objects -> Use (place), items -> Buy from vendor when Questie lists vendors and no drops (vendor place, waypoint), else Collect (drop zones), reputation -> Earn reputation (faction name). prereq_test: kill, collect, buy, accept, turn-in kinds and texts |
| R322-2 | Icon instead of "-" per step | Prereqs.lua STEP_ICONS: accept GossipFrame AvailableQuestIcon (!), turn in ActiveQuestIcon (?), kill CURSOR Attack (sword), buy INV_Misc_Bag_08 (bag), collect CURSOR Pickup, use CURSOR Interact, reputation INV_Misc_Note_02; text indented by the icon |
| R322-3 | No journal scrollbar when nothing scrolls | scrollBarHideable + OnShow check (as /qt), visibility set after each render and a frame later |
| R322-4 | "Upcoming Steps" not over the guide name | cause: since 3.2.1 the guide header's text is anchored to the journal book; the copy took that anchor. Copies now anchor only to their own frame; the text uses the template's original position (ns.headerTextPoint) |
| R322-5 | Journal button in Forever's art | Forever source (Gethe/wow-ui-source forever 4cd0ab75, 1.60.1.70888): Blizzard_MicroMenu Mainline LoadMicroButtonTextures(self, "Questlog") -> UI-HUD-MicroMenu-Questlog-Up/Down/Disabled/Mouseover; used at the atlas's proportions (22 px high), book icon fallback without the atlas. header_test. In-game look: not run |

## 3.2.3

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R323-1 | Back-one-step box only in RXP Style | user screenshot: the box shown in Forever Style. Forever never placed it but also never hid one placed before the switch (hide ran only when RXP Style left it unplaced); now hidden on every Forever layout. forever_test checks the hide |

## 3.2.4

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R324-1 | The journal button looks like a journal | user report: 3.2.2's Questlog atlas shows a "!" scroll. Now UI-HUD-MicroMenu-AdventureGuide-* (EJMicroButtonMixin, an open book; EJMicroButton is in Forever's micro menu per Camelot MicroMenuContainerOverrides, source 1.60.1.70888). header_test. In-game look: not run |

## 3.2.5

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R325-1 | Journal: total experience and gold missed if skipped, next to the quest the guide wants, in the title style | total over that quest and every prerequisite in its plan: experience from Questie's QuestXP (level-adjusted), gold from GetQuestLogRewardMoney (as Questie's own QuestXP.GetQuestRewardMoney; 0 where the game has no data). Extras.lua api.formatRewardTotals uses the title settings: db.xpOrb, db.xpColor (with opacity), db.goldCoins. rewardtotal_test.lua (text and icon forms, totals). In-game: not run |

## 3.2.6

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R326-1 | Visible height and Extra width under Scroll speed on Quest list | moved from the sizing page with their note; same settings and calls |
| R326-2 | "Advanced sizing" renamed "Advanced" | page title, README |
| R326-3 | Journal uses the /qt text size and font | Prereqs.lua styleText: each line, title, subtitle, hint and button at its font object's size x configTextSize in api.fontPath(); icons scale too; Config applyFonts calls api.refreshPrereqsFonts. journal_render_test.lua (stub frames: opens, Arial at 150 % = 18, back to 12). That test found build calling applyStaticFonts before its definition (would have errored on open); fixed with a forward declaration |
| R326-4 | Font dropdown fits the screen | Config buildChoice popup: rows in a scroll child; height max(12 rows, 60 % of the screen); mouse wheel, thumb on a track; opens on the current choice; above the box when there is more room. In-game: not run |

## 3.3.0

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R330-1 | Type a font in the dropdown, with auto-fill | Config buildChoice: lists with a font preview or 8+ choices get a type box (focused on open); typing filters (contains), the first choice starting with the typed letters is filled in its own spelling with the rest highlighted; no refill while deleting; Enter picks it (else the first match), Escape closes. dropdown_test.lua drives the real window: "ar" -> "Arial Narrow", one row, Enter picks it |
| R330-2 | Opacity sliders below the swatches | swatches anchored to the row top; Opacity row (size + 10 px x text size) below them |
| R330-3 | General opacity in Advanced for the tracker and its parts, not the GUIs | db.trackerAlpha 10-100 %: viewport (quests and guide inside it), header strip, background, divider, drag handle, scrollbar (its fade x the opacity), More quests, step buttons, the guide when pinned on UIParent. /qt and the Prerequisite Journal untouched |
| R330-3b | Sub-sliders RXP Tracker opacity and Quest Tracker opacity (user's follow-up) | db.guideAlpha on the guide module(s) and step buttons, db.questAlpha on the game's quest modules and More quests; both x general. dropdown_test: 0.5 x 0.5 = 0.25, 0.5 x 0.8 = 0.4, floor 10 % |
| R330-4 | Swatches and switches in higher definition | Textures/CircleHD.tga (256 px, 4x4 supersampled edge) and CircleShadow.tga generated for the addon, tinted with SetVertexColor, trilinear filtering; switch: edge pill + fill pill (whole even pixels), knob shadow and highlight; swatch: ring, dark gap, colour, highlight. In-game look: not run |
| R330-5 | Typed value box always visible | dark box (45 %) with a 1 px edge; 70 % on hover/typing, gold edge while typing |

## 3.3.1

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R331-1 | /qt opacity slider, always left of the Search bar | Config build(): label + slider + value anchored RIGHT to the search box's LEFT (fixed header row, not in the scrolling page); db.configAlpha 30-100 % in 5 % steps, mouse wheel; only the /qt window (dropdown lists, journal and tracker untouched); re-arranged on text size changes. dropdown_test: window opens at a saved 60 %; smoke2 builds in all modes. In-game: not run |

## 3.3.2

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R332-1 | Journal opacity slider beside its close button, on the left | Prereqs.lua: label + slider + value in the title bar, anchored RIGHT to the close button's LEFT; db.journalAlpha 10-100 % (5 % steps, wheel); only the journal; follows the /qt text size; title left-aligned so it never overlaps. journal_render_test: opens at a saved 50 % |
| R332-2 | Minimum 10 % on both window opacity sliders | Prereqs and Config MIN_ALPHA 0.1 |

## 3.3.3

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R333-1 | No Lua error at login | user report: 136x Core.lua:43 attempt to call a nil value. applyQuestAlpha (3.3.0) called questAlpha, a local defined further down, so it read an undefined global. Definitions moved above their use. The stub tests missed it: their environment answers any unknown global with a stub. New check globals_audit.py (every build): global reads of names the file declares local, unusual lowercase global reads, global writes other than the saved variables; it flags this bug in 3.3.2 and is clean on 3.3.3 |

## 3.3.4

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R334-1 | Forever Style: ! and ? left of the journal book; a step count ("4/73") in their place | Header.lua: ! at the template text position, ? after it, the book after ?, the name after the book ending before the count; count = progress/total in the header font, grey as RXP Style's "Step X of Y", right of the name and left of < >. header_test checks the order and "73/200". In-game: not run |

## 3.3.5

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R335-1 | Layer at the bottom of Advanced with a warning | Layer heading, red "Warning: only change this if you know what you're doing." note (what it does, the ranges, that Defaults resets it with every quest tracker setting: api.resetDefaults restores DEFAULTS.layer and calls applyLevel), then the slider, last on the page. smoke2 builds the window |

## 3.3.6

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R336-1 | "Guide" under RXP Tracker renamed "Themes & guide" | Config page title; page key "guide" unchanged, so /qt guide, the ? button and Shift+right-click still open it. smoke2 builds and opens the guide tab |

## 3.3.7

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R337-1 | Forever Style: clicking the guide name opens/closes RestedXP's guide window, as RXP Style's logo | Header.lua: a button over the header text (left click), same ns.toggleHidden and tooltip as the logo; highlight on hover; SetPropagateMouseClicks(true) so right-clicks still reach the guide's menus (protected in the Forever API: called out of combat only, retried after combat). header_test: click toggles once. In-game: not run |

## 3.3.8

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R338-1 | ! tooltip: no version, "Left-click: Browse Guides" | browse button passes its own heading "RestedXP Guides" (other tooltips keep the release in their heading) |
| R338-2 | Journal tooltip: "Requires Questie." | Header.lua journal tooltip |
| R338-3 | ? tooltip without "Shift+right-click: /qt" | line removed; also the i line corrected to the 3.1.2 behaviour (quest log or waypoint, Shift-click goes to the step) |

## 3.3.9

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R339-1 | No Shift-click to go to a step; not in the tooltips | Rows.lua infoClick: Shift branch removed; i tooltip and ? tooltip lines removed. forever_test: Shift-click opens the quest, no SetStep |

## 3.3.10

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3310-1 | More quests: track with Alt-click instead of Shift-click | MoreQuests.lua click handler IsAltKeyDown and its tooltip line; nothing else in More quests changed. more_test unchanged |

## 3.3.11

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3311-1 | Journal: the skipping line on its own line below "Guide step N wants this quest" | Prereqs.lua render: second info line, only when there are rewards to show. journal_render_test passes |

## 3.3.12

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3312-1 | No "track it when there is room" in More quests | MoreQuests.lua: Alt-click branch removed; tooltip "Click: open in the quest log."; nothing else changed. more_test unchanged |

## 3.4.0

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R340-1 | Journal: potential quest item rewards after the gold, with item tooltips | items from Questie's Item.questRewards reverse index (Questie.lua api.questRewardItems; built over several frames, the journal redraws when ready); every item of the quest and its prerequisites once; icons (C_Item.GetItemIconByID) beside the heading when they fit, else on a row below; GameTooltip:SetItemByID on hover |
| R340-2 | Gold total adds the highest vendor value among each quest's reward options | per quest the highest sell price (C_Item.GetItemInfo 11th value) of its reward items; items not loaded yet are requested (RequestLoadItemDataByID) and the journal redraws on GET_ITEM_INFO_RECEIVED (at most every 0.5 s). Questie does not separate choices from fixed rewards, so all of a quest's reward items count as its options. journal_render_test: 12500 + 2 x 1200 = 14900, 2 icons, tooltip, load request. In-game: not run |

## 3.4.1

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R341-1 | Text size slider usable | user report: very glitchy. Each drag step rescaled every text and re-laid out the page, which resized and moved this slider (width min(.., 220 x size), row height) under the cursor, changing the value again; since 3.2.6 each step also redrew the journal. Now (item.applyOnRelease) dragging only updates the shown value; the setting applies on mouse up (or when hidden mid-drag); arrows, wheel, typed values apply at once; an unchanged value does nothing. dropdown_test: not applied while dragging, applied once on release, wheel at once. In-game: not run |

## 3.4.2

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R342-1 | Text size slider stable while dragged | user video (3.4.1, 0.58 s, 60 fps): the value flips 106 % <-> 132 % every few frames with the button held; each applied size resized the slider, moving the thumb against the still cursor. 3.4.1 depended on the slider's OnMouseDown, which the game doesn't fire for a grabbed thumb. Now: OnValueChanged with IsMouseButtonDown("LeftButton") only stores the value; an OnUpdate watcher applies it when the button is up (and on hide). dropdown_test: held = not applied, released = applied once, wheel = at once |
| R342-2 | Journal text keeps its size | user screenshot: text far larger than the window. styleText read the font string's current size (which a SetFont changes) and scaled it again each redraw. Now from the font object's GetFont. journal_render_test stub now keeps SetFont sizes like the game; four redraws at 150 % stay 18 (fails on 3.4.1). Same pattern searched across the addon: none left |

## 3.4.3

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R343-1 | In a dungeon its zone is shown first (closest zone) | ZoneSort.lua: IsInInstance party/raid/scenario -> instance name (GetInstanceInfo, else GetRealZoneText); a quest whose zone header matches it or the real zone text ("The " ignored) gets distance -1, ahead of every bucket. Without a map (many dungeons) the place keeps zone and instance; the other zones use the last outdoor position. The cached place is cleared on PLAYER_ENTERING_WORLD and ZONE_CHANGED_NEW_AREA. Alphabetical order unchanged. dungeon_test.lua (outside, inside "The Deadmines" vs "Deadmines", rest kept, alphabetical); prox_test and zone_test pass. In-game: not run |

## 3.4.4

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R344-1 | Quests for the dungeon filed under other zones | with Questie (integration on): a quest whose Questie points (open objectives; the turn-in once complete) lie in the dungeon you are in, matched by the game map of Questie's area or by the area's name ("The" ignored), gets -0.5: its zone right after the dungeon's (-1), the quest first in its zone. Quest log headers decide the zone, so the quest stays under it. Without Questie: unchanged (3.4.3). dungeon_test: Deadmines, Westfall (dungeon quest first, then the ordinary one), rest by distance; outside and alphabetical unchanged. In-game: not run |

## 3.4.5

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R345-1 | Text size maximum 125 % | slider 80-125; ts() and the journal's textScale clamp to 0.8-1.25, so an older saved 1.6 reads as 1.25. dropdown_test: saved 160 % shows as 125 % |
| R345-2 | /qt text stays inside the window | minimum window size x max(text size, 1) (720 x 480 -> 900 x 600 at 125 %, never beyond the screen), applied at build and on text size changes, enlarging a smaller window; sidebar width 196 x max(text size, 1), panel anchored to the sidebar. dropdown_test: grows to at least 900 x 600; smoke2 builds. In-game: not run |

## 3.4.6

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R346-1 | Journal: no ", from step N"; < > to the previous / next zone guide and its missing prerequisites | > follows the shown guide's #next (first of ";", "Group\\Name" or a name in its own group); < goes back the way > came, else to a guide whose next is this one; guides read with RestedXP's FetchGuide (parsed, not loaded; RestedXP keeps its own guide). Another guide is checked from its first step; back at the current guide the view resets; each opening starts at the current guide. Arrows (spellbook page art) right after the name, disabled at the ends; the name is cut to keep them inside the window. Started by an earlier run of this request (stopped mid-edit, files unchanged for 2+ minutes), finished here. journal_render_test: chain Ashenvale -> Feralas -> Tanaris, both directions, ends disabled, RestedXP guide unchanged. In-game: not run |

## 3.5.0

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R350-1 | Journal: dropdown beside < > to choose the guide | "Guides" button (theme red button) opens a list of the shown guide's group from RestedXP's guideList[group].names_ (its guide menu order; nothing parsed until chosen), current marked, shown highlighted, wheel-scrollable, opens on the shown guide; a pick shows that guide (current -> view reset). journal_render_test |
| R350-2 | Profiles under Settings Window: save, load, multiple, delete, import, export; "Default" on first use | Tracker/Profiles.lua: profiles in RXPForeverTrackerDB.profiles (account-wide), activeProfile; snapshot of every key of both settings tables except bookkeeping (profiles, ahValue, conflictKept, savedAutoWatch, zoneHidden, configPage/Tab, removed keys; guide: onboarded, questFocus*, hidden). Active profile saved on PLAYER_LOGOUT and before a load; load writes the profile and reloads (StaticPopup confirm); delete refused for the active profile (confirm); export "RXPFT1:" + base64 of a typed text serialisation; import parses it without running code, keeps only string keys whose value type matches the setting in use. /qt page: status (active, count, last action), Profile choice, Load / Save over / Delete / Export, New profile name + save, export box (select-all), import box + name + Import. New "input" control (one-line or scrolling multi-line). profile_test.lua (18 checks incl. Lua code in a string refused and not run); dropdown_test drives Export on the real page |
| R350-3 | RXP Tracker: upcoming steps stop growing after 2; scrollable with options like the quest tracker's | Rows.lua: only upcomingShown (default 2) upcoming entries are laid out, from an offset; the wheel on upcoming rows (and the Upcoming Steps header) moves it, at the ends it calls Core's tracker wheel; offset back to 0 when the first upcoming step changes; 3 px bar beside them (thumb = shown/total), options: Shown at once 1-20, Scrollbar, Only on mouseover, Scrollbar colour (with opacity). MAX_FOLLOWING 8 -> 20. upcoming_test.lua (7 ahead, 2 shown, scroll, stop, hand-off, reset, no bar when all fit). In-game: not run (wheel on blocks, bar placement) |
| R350-4 | Journal: later guides slightly greyed, still viewable (user's follow-up message) | isLater: after the current guide in its group's menu order, else along the #next chain (raw guide data); content at 60 % alpha, "(later guide, higher level)" after the name, later entries grey in the Guides list. journal_render_test |

## 3.5.1

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R351-1 | /ao replaced with /rt | SLASH_ALLOBJECTIVESRXP1 = "/rt"; /rt in the help and status lines, the guide page hint (also 0-8 -> 0-20), README, Settings.lua comments. Kept: the note about the separate old guide addon ("Use /ao", that addon's own command) and history entries. No built-in /rt found in the reference material; not checked in the client |

## 3.5.2

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R352-1 | No steps left: > starts the next zone guide instead of greying out | SkipBox.lua: RestedXP's functions.next(false) gives the next guide's group and name without loading (its #next list, season, faction, hardcore choices); > enabled when there is one; at the last step a click calls functions.next() (RestedXP loads it, as its own "next guide"), chat line names it; tooltip "Last step: start the next guide, <name>." Greys out only when no next guide exists. forever_test. In-game: not run |

## 3.5.3 (third optimization pass)

Same priorities as 3.0.5 / 3.0.8: per-frame and per-update CPU first, then memory, then leftovers; no visible change
except the user's < request (sent during the pass).

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R353-1 | Journal: less work per redraw | plans (up to 250 accept steps x Questie lookups) cached per shown guide + step (+ Questie ready); fonts, item data, resize redraw from the cache; opening, Refresh, another guide, QUEST_ACCEPTED / QUEST_TURNED_IN / QUEST_REMOVED rebuild. < > / Guides enable state per guide once (previousGuide scanned every guide and both read guides in full on each redraw). isLater once per redraw. GET_ITEM_INFO_RECEIVED (frequent) registered only while open. journal_render_test: font redraws make no new plan lookups; prereq_test |
| R353-2 | RXP Tracker: less per frame / per update | upcoming scrollbar's OnUpdate set only with "Only on mouseover" (it ran every frame while shown); Forever header: no SetText / SetFont for an unchanged name, count or font. upcoming_test checks no OnUpdate unless mouseover |
| R353-3 | Dungeon sort: fewer Questie calls | per Questie area, "inside this dungeon" cached per visit (instance + map); dungeon_test passes |
| R353-4 | Leftovers | unused exports removed: api.circlesMoved, api.withTrackerAlpha, api.saveActiveProfile, ns.upcomingWheel (api.profileCodec kept: profile_test uses it). Every OnUpdate / ticker since 3.0.8 checked: each stops itself or runs only while active |
| R353-5 | < at the first step goes to the previous zone guide (user, during the pass) | SkipBox.lua: a guide whose #next (any of ";", "Group\\Name" or a name in its own group) names the current guide and IsGuideActive; cached per guide; RXP:LoadGuide (RestedXP resumes at its saved progress); tooltip names it; greyed only without one. RXP Style's back box unchanged. forever_test |
| Checks | 29 stub tests, smoke2 in 4 modes, globals audit: pass. In-game CPU/memory: not run |

## 3.5.4

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R354-1 | Journal label "(previous guide)" instead of "(not your current guide)" | Prereqs.lua subtitle for a shown guide that is neither the current one nor later; journal_render_test |

## 3.5.5

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R355-1 | Journal < > don't grey out while jumping between guides | Prereqs.lua: routes built from RXP.guideList groups whose name has "Forever Dungeon Guide" / "Forever Guide" (faction suffix (A)/(H) matched to UnitFactionGroup; IsGuideActive; chapters skipped), sorted by the name's level range; < > = previous / next entry of the shown guide's list, enabled by its position (no parsing); next-chain kept only for guides in neither list. Routes and the chain cache rebuilt on a fresh render (the old per-guide cache was never cleared). journal_render_test: a broken #next still reaches Tanaris; > > from the first guide; greys only at the ends |
| R355-2 | Guides dropdown: only the Dungeon Guide and Open World Guide groups | headings "Dungeon Guide" / "Open World Guide" (not clickable), then their guides; Alliance group, "Dungeon Quests" group and an inactive guide left out; later guides greyed within the current guide's list. journal_render_test |
| Checks | stub tests, smoke2 in 4 modes, globals audit: pass. In game (Witchcraft): not run |

## 3.5.6

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R356-1 | Journal < > Guides fixed at the right, on the name's line | Prereqs.lua: Guides RIGHT at f TOPRIGHT (-PAD, HEADER_Y), > and < to its left; the name centred on HEADER_Y at the left, width capped before the buttons; dropdown opens right-aligned under Guides. In game: not run |
| R356-2 | Quests don't scroll when the cursor is nearer the RXP Tracker | Core.lua nearerGuide: cursor distance to the guide's rectangle vs the nearest visible quest module / More Quests (screen pixels, clipped to the viewport); applies to the viewport wheel and the upcoming-steps hand-off; the scrollbar always scrolls; no quest in view = scroll as before. wheel_near_test |
| R356-3 | Back to a previous guide: no finished steps, upcoming limit kept | cause: RestedXP LoadGuide wipes RXPCData.stepSkip, so SetStep re-activates every earlier sticky step (active steps are not windowed). SkipBox.lua settleEarlierSteps marks sticky steps before your place skipped and sets the step again. forever_test |
| R356-4 | Quest titles page: horizontal position slider for titles + objectives, like the zone header slider | Config.lua slider (-20..150, "%+d px", db.questTitleX, default 0, last on the page); Extras.lua applyTitleX adds it to QuestObjectiveTracker.blockOffsetX (base captured once; out of combat; relayout), so title and objectives move together; More Quests measures blocks so it follows; zone header labels (ZoneSort, MoreQuests) subtract it. In game: not run (needs blockOffsetX to be a number on the Forever quest module) |
| Checks | stub tests, smoke2 in 4 modes, globals audit: pass. In game (Witchcraft): not run |

## 3.5.7

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R357-1 | Zone header vertical position slider under the horizontal one | Config.lua slider (-20..40, "%+d px", db.zoneHeaderY, default 0, enabled with zone headers); added to the label's y in ZoneSort.lua and MoreQuests.lua (and More Quests' redraw key). In game: not run |
| Checks | stub tests, smoke2 in 4 modes, globals audit: pass |

## 3.5.8

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R358-1 | Rename "Guide in the tracker" to "Tracker settings" | Config.lua (both branches), Rows.lua comment, README. smoke2 builds the window |
| R358-2 | "Own window": RXP Tracker detached into a movable window; quests fill the space, make room on reattach | tracker db.guideDetached / guideWindowPos. Objectives/tracker/Tracker.lua: detached place() anchors the module TOPLEFT to RXPForeverTrackerGuideWindow (first time left of the tracker) and chains the next Blizzard module to the previous one (or the header); grip bar above it (drag, saved position, tooltip); granted height = screen; container collapse ignored. Tracker/Core.lua detectMode: no guide while detached (no fixed strip, not scrolled, parent UIParent, opacity as pinned); upcoming-steps wheel hand-off off. Combat: refused with a chat line. "Reset window position" button. In game: not run |
| R358-3 | Futureproof against RestedXP updates | Objectives/Core.lua: required = AceEvent, RXP.v2, RXP.settings, RXP.RXPFrame, RXP.SetStep, RXP.GetGuideProgress (missing: one line naming them, own windows, tracker unaffected); ns.hookRxp for every hook on RestedXP (missing listed in /rt status); ns.isSecret / itemCooldown / isPlayerSpell / L / texture / playerClass / guideFontSize / rxpProfile / rxpRelease with game fallbacks; Readers textStyle / paint / timerBars defaults; ns.guard: 3 failed renders in a row stand the display down for the session (one line; PLAYER_LOGOUT restores the saved setting; /rt toggle resumes). Journal groups by words + current-group fallback. futurerxp_test: each of 59 RestedXP parts used removed in turn: no load error; breaker mode; all unit tests updated |
| R358-4 | Scrollbar width sliders, quest tracker and RXP Tracker | Quest list: db.scrollbarWidth 2-30 (default 10, layoutBar + thumb; side check uses it). Tracker settings > Upcoming steps: upcomingScrollbarWidth 1-12 (default 3) in placeUpBar. In game: not run |
| Checks | all unit tests, smoke2 in 5 modes, futurerxp removal sweep + breaker, globals audit: pass. In game (Witchcraft): not run |

## 3.5.9

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R359-1 | (REVERTED in 3.5.10 at the user's request) Upcoming steps don't cover the "Quests" header (user screenshot: wrapped step text over "Quests 31/40") | Tracker/Core.lua: lowestShown also counts shown FontStrings with text (text wrapping past its line frame); guideTooTall: a guide needing more than the strip may have (window - 100) is not fixed on top but scrolls with the quests (24 px hysteresis; decision kept through combat); /qt debug names it. tall_guide_test. In game: not run |
| R359-2 | Conflict prompt: turn off only Questie's tracker, not Questie | Tracker/Conflicts.lua: Questie case → QuestieLoader:ImportModule("QuestieTracker"):Disable() (Questie 12.7.0: sets profile.trackerEnabled = false, reloads), fallback sets the profile option and reloads; button "Turn off Questie's tracker"; text says the rest of Questie keeps working. questie_conflict_test (module and fallback), conflict_test unchanged |
| Checks | all unit tests, smoke2, futurerxp breaker, globals audit: pass |

## 3.5.10

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3510-1 | Undo R359-1 (user) | Tracker/Core.lua identical to 3.5.8 (diff); tall_guide_test removed. R359-2 (Questie tracker only) kept |
| Checks | unit tests, smoke2, globals audit: pass |

## 3.5.11

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3511-1 | A very long current step pushes the quest tracker down; the "Quests" header is never collided with (user screenshot: RXP Style, long step text over Quests) | Tracker/Core.lua: lowestShown counts shown FontStrings with text (wrapped text past its line frame); measurePinned has no cap (was window - 100 px): the quests start DIVIDER_GAP below the lowest text, the list keeps 50 px minimum and may extend past the window's bottom. Applies while the RXP Tracker is fixed on top (the usual case); not while a scenario section above it makes it scroll. long_step_test. In game: not run |
| Checks | unit tests, smoke2, globals audit: pass |

## 3.5.12

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3512-1 | Forever Style is the default theme | Objectives/Core.lua DEFAULTS.theme = "forever"; load normalises anything but "rxp" to "forever"; Settings.setTheme likewise; Config lists "Forever Style (default)" first. Existing saved "rxp" kept (it cannot be told apart from a choice). Tests, smoke2, audit: pass |

## 3.5.13

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3513-1 | Extra width up then back to 0 must not leave the drag bar / tracker parts wide (user video) | cause: onSize took the tracker's width while it hangs between the window's corners (= natural + extra) as the natural width, so extra piled up. Tracker/Core.lua onSize: width is Blizzard's only while the tracker is not anchored to the window. In game: not run |
| R3513-2 | Extra width must not stop text being cut off; rely on word wrap | applyModuleWidths: modules and their line-width fields get only the Quest Tracker scale correction (no extra); module SetWidth hook no longer re-adds extra; Extras prepareText widens text only with word wrap on. Config note updated |
| R3513-3 | Drag bar releases on button up, not a second click | Core createHandle: OnUpdate stops when IsMouseButtonDown("LeftButton") is false; OnDragStop also stops. Own-window grip rewritten the same way (StartMoving does not move frames in Forever) |
| R3513-4 | Space before coin icons in the Prerequisite Journal | Extras gold(copper, coins, spaced); formatRewardTotals(xp, money, spacedCoins); Prereqs passes true. rewardtotal_test, coin_test |
| Checks | all unit tests (exit codes scanned), smoke2, globals audit: pass; more_test stub ERROR lines predate this (also on 3.5.8) |

## 3.5.14

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3514-1 | Fix Questie.lua:675 "attempt to index local 'o' (a number value)" (user error report, quest 1368, objectives[4] = {92, 3000}) | cause: Questie's reputationObjective is one {factionID, value} pair; objectiveSteps iterated it as a list. Questie.lua: objectiveEntries / firstId keep only table entries for kinds 1, 2, 3, 5 (all readers: zones, place, map things, steps); reputation read as a single pair (or a list of pairs). prereq_test: a {92, 3000} objective plans without error and reads "Earn reputation with <faction>"; the same test fails on 3.5.13 |
| Checks | all unit tests, globals audit: pass |

## 3.5.15

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3515-1 | "Tracking and sorting" as its own /qt page under Quest Tracker | Config.lua: page("tracking", "quests", "Tracking and sorting") after Quest list holds Track, Sort zones, List quests past the tracking limit (same controls, same settings); Quest list keeps its Reset position / Scroll to top buttons; page reset = the Quest Tracker reset. README, zone headers note. smoke2 builds the window; dropdown, text size and profile tests pass |

## 3.5.16

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3516-1 | "Tracking and sorting" listed last under Quest Tracker | Config.lua: the page is declared after Tooltips (sidebar follows declaration order). README order updated. smoke2 builds the window |

## 3.5.17

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3517-1 | /qt title more eye-catching, within the Forever art style | Config.lua title bar: game font 17 px with shadow, "RXP" cream / "Forever" gold / "Tracker" pale gold; RestedXP logo (only when RXPGuides is loaded) centred with the text; horizontal gold glow (0 to 16 % to 0); 110 px fading gold rules with 5 px rotated diamonds; gold gradient line under the bar. Approximate preview rendered (DejaVu stands in for the game font). smoke2 builds the window. In game: not run |

## 3.5.18

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3518-1 | /qt opacity slider left of the close button, like the Prerequisite Journal | Config.lua: holder parented to the title bar, RIGHT to close LEFT -6, slider 90 x 18 (as the journal); f.qtsFitTitle shortens the title rules (max 110 px, hidden under 12 px) and glow to keep clear of it, re-run on resize and text size. smoke2, text size test: pass. In game: not run |

## 3.5.19

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3519-1 | Going back to a previous guide must not make the RXP Tracker disappear (user: 41-400_41-41 Swamp of Sorrows; first load per session only, recovers otherwise) | Diagnosis (not reproduced in game): Snapshot.lua cached RXP.v2:BuildGuideStepsSnapshot()'s list until the next step change; for a guide RestedXP parses on first load in a session the list can still be empty at the first pass, so the module hid and stayed hidden. Fix: an empty list is never cached; while the current guide has steps it is read again every 0.25 s, up to 20 times per load (reset on step / guide change); SkipBox.stepBack clears the list after LoadGuide. empty_snapshot_test (fails on 3.5.18). In game: not run - if it still happens, the chat line about RestedXP data and /rt status will tell which path hid it |
| R3519-2 | Display name in the back-to-previous-guide line and tooltip | SkipBox.lua: guide.displayname or guide.name |
| Checks | all unit tests, smoke2, futurerxp breaker, globals audit: pass |

## 3.5.20

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3520-1 | /qt opacity slider above "Quest Tracker", on the search bar's line (replaces R3518-1, user changed mind) | Config.lua: holder on the window, LEFT at TOPLEFT (14, -56): the category list's left edge, centred on the search box (top -44, 24 tall); title rules fitted around the close button only. smoke2, text size test: pass. In game: not run |

## 3.5.21

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3521-1 | /qt category list: scrollable when out of room (no scrollbar), hide text that doesn't fit until it does; check only after resizing (user screenshot: list past the window bottom) | Config.lua buildSidebar: headers and entries in a ScrollFrame child (clips); mouse wheel scrolls one row (26 px x text size), clamped; sidebar.fit hides rows not wholly in view and clamps the scroll; run on window OnSizeChanged, on arrange (text size), on wheel and once after the window first shows; nothing per frame. smoke2 builds the window; settings tests pass. In game: not run |

## 3.5.22

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3522-1 | /qt bottom hint to the right of the category list | Config.lua footer: BOTTOMLEFT at the page panel's BOTTOMLEFT (+2, -32: 18 px above the window bottom as before), right edge before Close, one line. smoke2 builds the window. In game: not run |

## 3.5.23

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3523-1 | Resizing the settings window must not snap/glitch | Config.lua grip: StartSizing replaced by a cursor-following resize (OnUpdate while IsMouseButtonDown, top-left pinned by re-anchoring TOPLEFT to UIParent at the current corner, clamped to the text-size minimum f.qtsMinW/H and MAX_W/H, size saved on release). Same for the Prerequisite Journal grip (MIN/MAX from Prereqs.lua, render on release). f:SetScript("OnSizeChanged") → HookScript, so the 3.5.18/3.5.21 resize hooks (title rules, category list fit) are no longer dropped. smoke2, text size and journal tests pass. In game: not run |

## 3.5.24

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3524-1 | Category rows hidden while short must show again when the window grows | cause: fit ran in the window's OnSizeChanged, before the list (anchored inside) had its new height, so the old height was used. Config.lua: fit on the scroll frame's own OnSizeChanged, plus a deferred (next frame) fit after the window resizes; the title rules likewise on the title bar's OnSizeChanged. smoke2, text size test pass. In game: not run |

## 3.5.25

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3525-1 | Scale, x, y sliders for current step and upcoming steps; "Current step(s)" heading like "Upcoming steps"; upcoming sliders above "Shown at once" | guide db currentScale/X/Y, upcomingScale/X/Y (RANGES 0.5-2, -60..120, -40..60); Rows.lua prepareRow (SetScale, block.offsetX and fixedWidth/width before Blizzard's AnchorBlock - Blizzard_ObjectiveTrackerModule.lua forever 4cd0ab7: TOP to last block, LEFT at block.offsetX, RIGHT unless fixedWidth) and settleRow (TOP back to the unscaled gap + the group's y on its first row; module.contentsHeight corrected). upcoming_test: scale, offsets, width, top offsets, contents height, reset |
| R3525-2 | "Quests" header + collapse button colour with opacity, above the padding slider | Extras.lua applyQuestsHeaderLook (Text colour, MinimizeButton normal/pushed vertex colour + alpha); db.questsHeaderColor (false = game's), on every tracker apply; Config colour + "Game's header colours" button. In game: not run |
| R3525-3 | Colour with opacity for the line under "Quests", below that | header.Background (atlas UI-QuestTracker-Secondary-Objective-Header) vertex colour + alpha; db.questsLineColor. In game: not run |
| R3525-4 | N/40 on/off below "Usable quest items on the left", size and colour beside it, warning about the threshold colours | db.questCount / questCountSize / questCountCustom / questCountColor; MoreQuests updateQuestCount; Config check + indented size, custom-colour check (with the warning) and colour. In game: not run |
| R3525-5 | N/TOTAL on/off with size and colour | guide db stepCountShown / stepCountSize / stepCountColor; Header.lua (hidden = empty text so the name gets the room); Tracker settings controls. In game: not run |
| R3525-6 | Extra width must not move the Upcoming Steps / step divider lines | Objectives Tracker.lua place: module width from the tracker's natural width (api.naturalWidth); the Upcoming Steps header and the RXP Style divider are placed from the contents' left edge (contentsDX), so step x/scale do not move them either |
| R3525-7 | RXP Tracker scrollbar in the quest scrollbar's column | Rows.lua placeUpBar: centred on api.questBarColumn() (quest bar left/right in pixels); steps' right edge in the own window or before the quest bar exists. In game: not run |
| R3525-8 | Grey the RXP Tracker group without RestedXP Guides; grey Zone headers while Track has no zone headers; both still viewable | Config.lua page.dimmed (guide pages: RXPGuides not loaded; zoneheaders: not db.zoneSort); sidebar.refreshDim greys entries and a group header whose pages are all dimmed (icon desaturated); runs on every refreshConfig. smoke2 builds the window |
| Checks | all unit tests, smoke2 in 4 modes, futurerxp removal sweep, globals audit: pass |

## 3.5.26

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3526-1 | "Shown at once" -> "Steps shown at once" | Config.lua |
| R3526-2 | Line colour must change the line under "Quests" (user screenshot: the gold line) | that line is the tracker's own divider (Core.lua layoutDivider, atlas UI-World-Quest-golden-line): db.questsLineColor now sets its vertex colour + alpha too (applyDividerLook on change); the header Background stays tinted as well. In game: not run |
| R3526-3 | Label "Line under "Quests" header" | Config.lua |
| R3526-4 | Quest count opacity always | MoreQuests updateQuestCount: alpha from questCountColor[4] always, RGB only with questCountCustom; the colour control enabled whenever the count is shown |
| R3526-5 | Extra width under Advanced, note kept + warning | Config.lua Advanced page after the opacities; red warning text |
| R3526-6 | Word wrap on by default | DEFAULTS.wordWrap = true already; one-time migration (db.wrapDefaulted) switches it on for existing settings |
| R3526-7 | "Visible height" -> "Extra length", above "Show scrollbar" | Config.lua Quest list |
| R3526-8 | RXP scrollbar fades like the quest scrollbar | Rows.lua hoverCheck: per-frame fade (2 s after hover/scroll, 0.4 s), only while the bar is shown in mouseover mode; wheel marks activity |
| R3526-9 | Journal: only the current guide's list; next 2 yellow, next 2 orange, then red | Prereqs.lua guideMenu.open: the current guide's route (else the shown guide's, else both); entry.ahead tiers. journal_render_test: list, colours, arrows to the end |
| Checks | all unit tests, smoke2, globals audit: pass |

## 3.5.27

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3527-1 | Guides dropdown closes with the journal | cause: a later f:SetScript("OnHide") replaced the earlier HookScript that hides the dropdown; now HookScript. A scan of all files found no other SetScript after HookScript on the same frame and script. journal test, audit pass |

## 3.5.28

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3528-1 | "Line under "Quests" header" colours the line under "Quests N/40", not the line under the last upcoming step | Extras applyQuestsHeaderLook tints every texture region of QuestObjectiveTracker.Header (Background etc., not the collapse button, Shine, Glow), first, before the text; Core divider tint from 3.5.26 removed; errors from the settings change go to the error handler instead of being swallowed. In game: not run (the 3.5.25 version tinted header.Background only and was reported as not working) |
| R3528-2 | "Steps shown at once" under "Steps shown ahead" | Config.lua |
| R3528-3 | Switch left of < in the journal: show/hide previous guides in the list | themeKit.makeSwitch (settings pill style); db.journalHidePrevious; guideMenu.open skips entries before the current guide in its list; tooltip; name width allows for it. journal_render_test |
| Checks | all unit tests, smoke2, globals audit: pass |

## 3.5.29

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3529-1 | Tooltips for items linked in RXP Tracker steps | cause: the line template (Blizzard_ObjectiveTrackerShared.xml, forever 4cd0ab7) has hyperlinksEnabled but does not take the mouse, so link hover never fired. Rows.lua: each line takes the mouse once out of combat only when SetPropagateMouseClicks succeeds (clicks and hover pass on to the step); OnHyperlinkEnter shows GameTooltip:SetHyperlink (RestedXP's own handler first); click stays the template's SetItemRef. upcoming_test. In game: not run |
| R3529-2 | "Click here to copy link" opens a copy popup | RestedXP .link elements carry element.url; the line keeps its element; left-click opens StaticPopup RXPFOREVERTRACKER_COPY_LINK with the url selected (Ctrl+C), right-click goes on to the step; hover shows the address. upcoming_test. In game: not run |
| Checks | all unit tests, smoke2, futurerxp sweep, globals audit: pass |

## 3.5.30

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3530-1 | .clicknext steps start their guide from the RXP Tracker | element.next ("Group\\Name" or "Name") -> RXP.GetGuideTable / RXP.guides -> RXP:LoadGuide (pcall), step list re-read; hover "Click to start <name>". upcoming_test. In game: not run |
| R3530-2 | Missing prerequisites tooltip on accept / turn-in steps, click opens the journal | element.tooltip (string) shown on hover; with RestedXP's error icon (element.icon == RXP.icons.error) a hint and a left-click that opens the Prerequisite Journal (not closing it when open); numeric debug ids not shown. upcoming_test |
| R3530-3 | Steps skipped by level say so | element.step.tooltipText on hover. upcoming_test |
| Checks | all unit tests, smoke2, futurerxp sweep, globals audit: pass |

## 3.5.31

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3531-1 | Level-skip note reads "Steps skipped: XP requirements are exceeded" | Rows.lua stepNoteOf replaces RestedXP's "Step skipped: XP requirements are not met" (English or its translation via RestedXP's locale); other notes unchanged. upcoming_test |

## 3.5.32

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3532-1 | Collapsing the quest tracker hides More Quests too | MoreQuests.lua layoutMoreQuests hides while QuestObjectiveTracker:IsCollapsed() (as it already did for the whole tracker collapsed); SetCollapsed post-hook re-places it on the next frame. more_test: folded hidden, unfolded shown |

## 3.5.33

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3533-1 | Collapsing the main RXP Tracker must not hide Upcoming Steps | Blizzard's module collapse adds no blocks at all (Blizzard_ObjectiveTrackerModule.lua InternalAddBlock, forever 4cd0ab7), so Rows.lua overrides our module's ToggleCollapsed (called by the header button's OnToggle): db.currentCollapsed folds the current steps; an empty spacer row keeps the module laid out and holds the Upcoming Steps header; header art via Header:SetCollapsed; the upcoming header keeps the collapse art as its base. upcoming_test: fold shows only upcoming, unfold restores |
| Checks | all unit tests, smoke2, futurerxp sweep, globals audit: pass |

## 3.5.34

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3534-1 | Item tooltips in RXP Tracker steps (user: none on hover; copy link suspected too) | cause: guide text writes items as "|T icon|t[Name]" (plain text, e.g. Guides/forever Alliance-1-10_NightElf.lua), no hyperlinks; and 3.5.29 handed hover to RestedXP's hidden row and relied on SetPropagateMouseClicks. Rows.lua decorate: names of the step's own items (element ids of collect/destroy/questitemcount/retrieveitem/buy/equip/use/itemcount/bank/mount/toy; C_Item.GetItemNameByID, loaded on demand with one relayout) become |Hitem:ID| links; accept/turn-in quest titles |Hquest:ID|; lines with a url / next guide / note and no link wrapped in |Hrxpft:line|; OnHyperlinkEnter shows our own tooltip (+ RestedXP's notes), OnHyperlinkClick: rxpft actions or SetItemRef. Line mouse/propagation code removed. upcoming_test. In game: not run |
| R3534-2 | Scrollbar on the journal's Guides dropdown | Prereqs.lua: 6 px track + draggable thumb (theme colours) at the right, shown only when the list is longer than the box (14 rows), kept in step with the wheel and on open. journal test, audit pass. In game: not run |
| Checks | all unit tests, smoke2, futurerxp sweep, globals audit: pass |

## 3.5.35

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3535-1 | Upcoming steps show tooltips too | Snapshot.lua buildFollowing passes a per-step stand-in element { step = guide.steps[listRow.index] } (weak cache) to setLine; Rows decorate links its items/quest like a current step. upcoming_test |
| R3535-2 | Item tooltips "still very inconsistent" (user) | the preceding |T icon|t joins the link; names without a step id resolved with C_Item.GetItemInfoInstant(name); placeholders keep a bracket from being linked twice. upcoming_test. Step skipping reported with it is left as RestedXP's own behaviour (user: "could be RXP Guides being inconsistent") |
| Checks | all unit tests, smoke2, futurerxp sweep, globals audit: pass |

## 3.5.36

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3536-1 | Waypoint arrow page: scale slider | Objectives/Settings.lua get/setArrowScale: RestedXP profile.arrowScale (its "Arrow Scale", 0.2-2) and arrowFrame:SetSize(32 x scale) as its SettingsPanel does; nothing written when RestedXP's profile is not where expected. Config slider 20-200 %. arrowscale_test, smoke2, audit, futurerxp. In game: not run |

## 3.5.37

| ID | Requirement | Status / acceptance evidence |
|---|---|---|
| R3537-1 | Colour switcher and opacity slider under Arrow scale | guide db arrowColor (false = theme's slate / dark) and arrowAlpha (0.1-1); Pin.lua syncPin tints the pin body and RestedXP's chevron (af.texture), sets the pin's and RestedXP's arrow frame's alpha; ns.applyArrowLook on change. Config: custom-colour switch + colour, opacity slider. smoke2, settings tests, audit, futurerxp sweep. In game: not run |
| R3538-1 | RXP Tracker never skips steps or guides on its own | Audit: every SetStep/LoadGuide/functions.next call is user-initiated (back/forward, guide menu, click-to-start, back to previous guide). ns.nextGuideName and the QuestFocus look-ahead used functions.next(false), which can load a guide (season/mode mismatch, guideSkip fallback): replaced with read-only ns.peekNextGuide. forever_test (peek never calls next, redraws load nothing), full suite, smoke2, futurerxp sweep, audit. In game: not run |
| R3538-2 | Explain/control the jump to the end of a guide below your level | Cause: RestedXP's "Skip overleveled steps" (profile.enableXpStepSkipping, default on; functions.lua xp). /qt Tracker settings switch mirrors it (DetectXPRate on enable, as RestedXP's panel does); one chat line per guide when 3+ earlier steps were level-skipped after LoadGuide. levelskip_test. In game: not run |
| R3539-1 | Item tooltips on every item a step names (.use, .bankwithdraw lists, unloaded items) | Rows.lua stepLinks: ipairs over {e.ids, e.items, e.activeItems} stopped at a nil e.ids, so .use (activeItems) and .bankwithdraw (items) ids were never read; fixed. Unloaded items matched by the icon before the bracket (C_Item.GetItemIconByID / GetItemInfoInstant, instant); an icon shared by two items matches neither. upcoming_test. In game: not run |
| R3539-2 | Spell tooltips on class spells in the RXP Tracker | .cast ids, .usespell activeItems, .train id -> spell:ID links (bracketed by name or icon; unbracketed first mention). linkEnter SetHyperlink shows the spell tooltip. upcoming_test. In game: not run |
| R3539-3 | One general icon in front of Cast steps | decorate replaces a cast line's leading icon (RestedXP's spell texture) with INV_Misc_Book_09. upcoming_test. In game: not run |
| R3540-1 | Explain and control guides jumping to their end | RestedXP passes steps itself: SetStep skips steps above your level and step.completed ones; auto-skip conditions (isOnQuest / isQuestComplete / isQuestTurnedIn, ... functions.lua, unless profile.disableAutoSkip) and the XP skip. This addon makes no step move on its own (3.5.38 audit). /qt "Auto-skip steps" mirrors disableAutoSkip (inverted); a chat line after LoadGuide counts passed steps by reason ("Step skipped: ..." notes, step.level, xp elements); /rt why logs SetStep / LoadGuide / functions.next with the caller (this addon if its folder is in debugstack). levelskip_test. In game: not run |
| R3540-2 | Steps shown ahead / at once: 0-100 then All | ns.ALL_STEPS = 101; Snapshot limit math.huge; Rows upShown math.huge (no scrolling); slider format "All"; /rt all. Suite. In game: not run |
| R3540-3 | Journal: indent under each quest | info lines INDENT, prerequisites INDENT*2, their steps INDENT*3. In game: not run |
| R3540-5 | Tooltip for items named in the plural | Rows.lua nameForms: the name lookup also tries singular forms (-ies -> y, -es, -s); "[Superior Healing Potions]" on a .vendor step (no item id in the step). upcoming_test. In game: not run |
| R3540-4 | /qt section list scrollbar | 6 px track and draggable thumb right of the list, shown only while it does not fit; wheel and thumb share scrollTo; fit() places the thumb. In game: not run |
| R3541-1 | Diagnose guides jumping to their end (skip settings ruled out by the user) | /rt why: copy window; SetStep hook logs each step landed on / passed with flags (marked done, needs level, sticky, requires, active) and element states (tag id DONE/SKIP, Step skipped notes); UpdateStepCompletion hook logs the finishing step when loadNextStep is set; LoadGuide / functions.next logged; caller = this addon when its folder is in debugstack. levelskip_test. Awaiting the user's log |
| R3541-2 | Tooltips for vendor items named without an id ([Greater Healing Potions]) | Rows.lua KNOWN_ITEMS (potions, food, water, arrows, reagents) used only when the icon in front matches GetItemIconByID(id), or with no icon when the game's name matches; an icon that says no stops the bare-name pass. upcoming_test. In game: not run |
| R3542-1 | "- Pages" items show the Page 1 tooltip | Rows.lua nameForms adds "<book> - Page 1" for "<book> - Pages" / "<book> Pages"; KNOWN_ITEMS Green Hills of Stranglethorn - Page 1 (2725), Shredder Operating Manual - Page 1 (16645), icon-checked. upcoming_test. In game: not run |
| R3542-2 | Guides opening at their end (persists with only RestedXP loaded) | RestedXP resumes each guide at RXPCData.guideProgress[guide.key]; a guide once run to its end reopens there. Restart this guide (SaveGuideProgress(guide, 1) + ReloadGuide), Reset all (RXP.ResetGuideProgress, confirm popup), /rt restart. A skip (ours or RestedXP's box) sets element.skip in memory only until /reload; no addon can mark a quest complete in the game. levelskip_test. In game: not run |
| R3543-1 | Previous step never bounces back to the step you were on | SkipBox.lua wouldFinish (step.completed, every element completed/skip/textOnly, "Step skipped" notes) passed by previousStep (nearest plain step as fallback); stepBackFrom checks after 0.6 s and steps further back while progress >= origin (max 6). bounce_test. In game: not run |
| R3544-1 | Remove the two skip switches; guide progress buttons in Themes & guide | Config.lua: Skip overleveled steps / Auto-skip steps checks removed (api kept, unused); Guide progress buttons, popup and note moved to the Themes & guide page. Skip chat line and /rt why point to RestedXP's own "Skip overleveled steps" / "Disable step skips". levelskip_test, smoke2. In game: not run |
| R3545-1 | Guide progress buttons beside Choose a guide / Print status | Config.lua: one buttons row (Choose, Print, Restart, Reset all) with the note below; buildButtons wraps to a new 32 px line when the page is too narrow. Suite, smoke2. In game: not run |
| R3546-1 | Defaults resets only the open /qt section | Config.lua pageKeys: each control on the page is read once while both settings tables record the keys read (values set aside, restored at once, under pcall); Core resetDefaults(keys, label) and objectives settings reset(keys) reset only those (table defaults copied; position only on a full reset; minimap, track mode and own window only when on the page; own window re-attached). smoke2 (titles page keys), suite. In game: not run |
| R3547-1 | Tooltip on the Defaults button | Config.lua: HookScript OnEnter/OnLeave on defaultsButton; names the open page's title and what is not changed. smoke2. In game: not run |

## 3.5.48 (fourth optimization pass)

Same priorities as 3.0.5 / 3.0.8 / 3.5.3: per-frame and per-update CPU first, then memory, then leftovers; no visible change. Scope: everything added since 3.5.3.

| ID | Requirement | Evidence |
|---|---|---|
| R3548-1 | Per frame | Pin.lua syncPin: arrow colour compared as numbers (it formatted a string every frame). Every OnUpdate added since 3.5.3 checked: drag/resize grips, scrollbar thumbs and the fade stop themselves or run only while active |
| R3548-2 | Per update | Rows.lua decorate: link work (stepLinks tables, item/spell lookups, gsubs) cached per element by text and linkGeneration (bumped on every GET_ITEM_INFO_RECEIVED; the watcher starts with the first decorate); line wrap still per call. SkipBox: nextGuideName cached per guide, #next line and level ("none" kept 5 s while RestedXP registers guides); canStepBack / back-box alpha / tip use previousStep(nil, true), which stops at the first plain step. Header step counter: numeric colour compare (table.concat per redraw). Extras applyQuestsHeaderLook returns before GetRegions when no colour is set and none was applied. upcoming_test (cache hit / text change), forever_test |
| R3548-3 | Leftovers | removed api.get/setLevelSkip, api.get/setAutoSkip (switches removed in 3.5.44), ns.noteLevelSkips, ns.noteSkips, ns.stepBackFrom, ns.skipCounts, ns.CAST_ICON exports (unused). levelskip_test updated |
| Checks | 38 stub tests, smoke2 in 5 modes, RestedXP removal sweep, globals audit: pass. In-game CPU/memory: not run |
| R3549-1 | Back from a guide's first step opens the previous guide at its first step | SkipBox.lua stepBack: SaveGuideProgress(previous, 1) before LoadGuide (it returns to the saved place); SetStep(1) after loading if the loaded guide's own saved place still won (renamed key). forever_test. In game: not run |
| R3550-1 | Shift+click an upcoming step to make it current | Rows.lua: row.rxpUpcomingStep (upcoming entries only); row.OnHeaderClick (the block template's HeaderButton calls it) and a line OnMouseUp hook call ns.goToStep (RestedXP SetStep) on Shift+LeftButton; a link click in the same moment is left to SetItemRef. Info tooltip hint. upcoming_test. In game: not run |
| R3551-1 | Shift+right-click (not Shift+click) makes an upcoming step current | Rows.lua rowHeaderClick / lineUp: RightButton + Shift; jumpTo only for a numeric step. upcoming_test (Shift+left no, Shift+right yes, plain right no, current step no). In game: not run |
| R3552-1 | Mark a current step done (icon right of "Step N") | Rows.lua placeDone (Forever Style, active entries): ReadyCheck-Ready button; ns.markStepDone(n): each open objective OnComplete + skip (as RestedXP's ActiveStepElementPostClick), a text-only step gets step.completed; RXP.updateSteps, UpdateMap. upcoming_test. In game: not run |
| R3552-2 | Quest links and tooltips in upcoming steps; quest links to chat | linkText: an upcoming ref links each accept/turnin objective's title (first occurrence outside an existing link, insideLink); linkClick: quest link + Shift (either button) inserts GetQuestLink(id) (fallback quest:id:-1 with the title) via ChatFrameUtil.InsertLink / ChatEdit_InsertLink, else opens chat with it. upcoming_test. In game: not run |
| R3553-1 | Quest links to chat on Shift+left-click (user correction: not Shift+right) | linkClick: Shift+RightButton returns at once (the step's Shift+right-click handles it); quest chat link on Shift+left. upcoming_test. In game: not run |
| R3554-1 | Mark-done check: hollow, gold fill on hover | Rows.lua newDoneButton: two rotated strokes (skip box tick geometry, 11 px units), each a gold outline (sublevel 0) under a dark middle (sublevel 1); OnEnter paints the middles gold, OnLeave back. upcoming_test. Visual check in game: not run |
| R3555-1 | Work around RestedXP's reward-choice error (RXPGuides.lua:919, v4.11.36: GetItemInfo(nil) when GetQuestItemLink("choice", i) is not loaded) | Objectives/features/RxpFixes.lua: RXP.QuestAutomation wrapped (ticker path) and RestedXP's quest event frame OnEvent re-set to the wrapper (found by EnumerateFrames, script == original); on the reward window (RestedXP's own window order) with 2+ choices and a missing link it returns early and requests the item ids (GetQuestItemInfo 6th return); otherwise calls RestedXP. No Blizzard function replaced. rewardfix_test, removal sweep. In game: not run |
| R3556-1 | Mark-done check larger and in the Forever style | Rows.lua: 1.3x the heading font; per stroke a BACKGROUND ADD glow (hover only), a shadow offset down-right, a rim (C.on; hover C.ring) and a middle (C.onKnob; hover gold 1/0.82/0.25), colours from Tracker/Config.lua C. upcoming_test. Visual check in game: not run |
| R3557-1 | Softer hover on the mark-done check; tooltip title only | Rows.lua: hover fill C.thumb (0.71/0.58/0.39), hover rim 0.86/0.74/0.47, glow alpha 0.15; doneTooltip keeps only "Mark step N done". Suite. Visual check in game: not run |
| R3558-1 | Back to "41-400_41-41 Swamp of Sorrows" must not leave no guide | That guide is real (two copies: Forever Guide (H) and Forever Dungeon Guide (H), #name 41-400_41-41..., #displayname 41-41...); the internal name is only how RestedXP files it. stepBack: after LoadGuide, a failed call or an empty/no current guide reloads the guide you left (GetGuideTable(group, name)) and says why; previousGuide skips internal / disabled guides (LoadGuide declines them). forever_test. Cause of the user's unload not reproduced: needs /rt why or the chat line from 3.5.58 |
| R3558-2 | Journal Guides list: display names | Prereqs.lua route entries carry label = displayname (GetGuideTable); row text label or name. In game: not run |
| R3559-1 | < must not fight RestedXP (user: glitchy; RestedXP's "Go to step X" works) | RestedXP's Go to step is SetStep(n). SkipBox: skippedStep (element.skip or "Step skipped" notes; not element.completed / step.completed, which persist from an earlier pass); one SetStep; one retry only when progress == the step you left after 0.6 s and no newer click (backClicks token); the 6-try loop removed. bounce_test (stale done not passed, skipped passed, one retry only, no fight on other moves, two quick clicks). In game: not run |
| R3560-1 | < keeps stepping back while RestedXP bounces to the step you left | SkipBox stepBackFrom: each 0.6 s check, progress == origin and no newer click -> next earlier step; stops on any other progress, a new click, no earlier step, or 40 tries (guard). bounce_test (5 -> 4 -> 3 -> 2, stops when it stays). In game: not run |
| R3561-1 | Restart button between < and > (first step; again: back) | Header.lua: foreverButton with Interface\\Buttons\\UI-RotationLeft-Button-Up/Down (present in Forever source: Blizzard_DressUpFrames), RotationRight while a return is pending; desaturated/0.6 alpha when unusable; anchored next <- restart <- prev. SkipBox: ns.restartToggle (remember progress per guide table, SetStep(1); again SetStep(saved)), canRestart, restartPending, restartTip. restart_test, header_test. In game: not run |
| R3562-1 | Restart button aligned and in the < > colours | Header.lua restartButtonFor: Interface\\Buttons\\UI-SquareButton-Up/Down/Disabled (Forever ObjectiveTrackerShared.xml QuestObjectiveFindGroupButtonTemplate) + Interface\\Buttons\\UI-RefreshButton icon at 50 % tinted gold (1/0.82/0), mirrored while pending, grey when disabled, -1/-1 while pressed; same size and anchors as the page buttons. header_test, restart_test. Visual check in game: not run |
| R3563-1 | Restart lands on the guide's real first step (41-41 Swamp of Sorrows) | That guide's step 1 is #optional .maxlevel 43,SoSSkip: past level 43 RestedXP jumps to the SoSSkip label mid-guide. SkipBox firstStep: first step not sticky, not optional, not above level, not skipped, with no element carrying a jump label (e.ref); canRestart / restartToggle use it. restart_test. In game: not run |
| R3564-1 | < must not roll over into later steps; go back a zone guide instead | SkipBox: jumpStep (an element with a label to jump to, e.ref) never a back target; with no other earlier step, ns.backToPreviousGuide. stepBackFrom: progress past the step you left after 0.6 s -> previous guide, or SetStep(origin) with none. backToPreviousGuide: after LoadGuide, RXP.nextStep cleared (the opening jump step asks for it while loaded) and SetStep(firstStep). bounce_test, forever_test. In game: not run |
| R3565-1 | Journal: for a later guide, name the zone guide that completes the prerequisites | Prereqs.lua guidesBefore: route entries from the current guide (from your step) to the one before the shown later guide (FetchGuide); turnins per guide (weak cache: turnin questId and ids); doneOnTheWay gives the first guide handing in each uncovered prerequisite; info line after "Guide step N wants this quest." names them (all / some / none), prerequisite tags "done in <guide>, step N". journal_render_test. In game: not run |
| R3566-1 | /rt why in the /qt and journal look, easy to understand | Objectives/features/WhyWindow.lua: theme kit (Tracker/Config.lua) window, title bar, close, dark panel; summary (guide/step, level, both RestedXP skip settings on/off with their meaning, skipped counts by reason), moves newest first as sentences (ns.describeMove) coloured by who (tracker buttons blue, RestedXP gold), live update (ns.whyChanged), Copy / Clear / Refresh. SkipBox: structured log entries with objective words. Chat fallback when the kit is missing. whywindow_test, levelskip_test. In game: not run |
| R3567-1 | Rename the /rt why window | WhyWindow.lua title "Why did guide skip?". whywindow_test |
| R3568-1 | Mark-done must finish the step and go to the next one | Rows.lua markStepDone: after the skips (as RestedXP's box), the step you are on -> SetStep(progress + 1) at once; a sticky step -> RXPCData.stepSkip[n] = true and SetStep(progress); RegisterForClicks("LeftButtonUp") on the button. upcoming_test. Cause of RestedXP not finishing it on its own not reproduced; in game: not run |
| R3569-1 | Shift+click < > changes zone guide | SkipBox: stepBack / stepForward check IsShiftKeyDown -> ns.backToPreviousGuide / ns.forwardToNextGuide (peekNextGuide, GetGuideTable); both through loadGuideAtStart (saved place 1, LoadGuide, failed / empty load reloads the guide you left, nextStep cleared, SetStep(firstStep)); tooltips add the Shift+click line. bounce_test. In game: not run |
| R3570-1 | Tooltip gold includes the best item reward's vendor value | Extras.lua readItems returns the best { value, name } (vendorValue x count); addRewards: Gold = money + max(best choice, best fixed reward), grey "includes X from selling <item>" line; shown when only items have value. rewardvendor_test. In game: not run |
| R3571-1 | No Gold line just for an item's vendor value | Extras.lua addRewards: Gold line (with the vendor value added) only when GetQuestLogRewardMoney > 0. rewardvendor_test |
| R3572-1 | Smaller "includes ... from selling" line | Extras.lua smallLastLine: <tooltip>TextLeftN:SetFontObject(GameTooltipTextSmall); OnTooltipCleared hook puts GameTooltipText back on the lines changed. rewardvendor_test. In game: not run |
| R3573-1 | Green check before a finished quest's title (RestedXP's skip-step tick), left of other icons | Extras.lua: questComplete (C_QuestLog.IsComplete, else GetInfo isComplete); render puts api.COMPLETE_CHECK in the first title slot (independent of Condense); placeTitleIcons draws it with checkWidget/placeCheck (dark box, 1 px light edge, two rotated green strokes in RestedXP's 11 px geometry, 90 % of the icon size); hidden when not finished. MoreQuests: entries carry complete, check first, signature includes it. completecheck_test. In game: not run |
| R3574-1 | Check: tick only, independent of the title; switch + scale + opacity; Icon opacity | Extras.lua placeCheck(fs, complete): two green strokes only, anchored RIGHT to the title's TOPLEFT (-2 px), takes no title room; db.completeCheck / completeCheckScale / completeCheckAlpha (Core DEFAULTS); placeTitleIcons applies db.iconAlpha. MoreQuests calls api.placeCheck after each title; hideTitleIcons hides it. Config: "Checks on finished quests" above "Icons on Elite+ quests" with Check scale / Check opacity (24 px indent), "Icon opacity" under "Icon size". completecheck_test, icon_test, smoke2. In game: not run |
| R3575-1 | Elite+ icons drawn separately left of the title, like the check | Extras.lua placeTitleIcons(fs, icons): icons anchored left of the title's TOPLEFT (2 px gap, last icon nearest, step = icon size + 3), returns "" (no indent; spacesFor and the marker offset removed); fs.qtsIconsWidth tells placeCheck to sit further left. MoreQuests the same. icon_test, completecheck_test. In game: not run |
| R3576-1 | Check colour swatch with its opacity; outline switch | Extras.lua: db.completeCheckColor {r,g,b,a} (false: green at completeCheckAlpha), strokes tinted, frame alpha = a; db.completeCheckOutline: black strokes 0.55 units larger behind (BORDER layer). Config: "Check colour and opacity" (color with alpha, replaces the Check opacity slider) and "Outline the check", both under the switch (24 px). completecheck_test. In game: not run |
| R3577-1 | Check on top of the Elite+ icon; icon at 35 % when finished | Extras.lua placeTitleIcons records qtsNearIconX (centre of the icon next to the title); placeCheck centres the check there when icons exist (else RIGHT of the title -2 px) and sets a finished quest's title icons to min(Icon opacity, 0.35). completecheck_test. In game: not run |
| R3578-1 | Elite+ icon next to the title, star further out; check on the Elite+ icon | Extras.lua render: attunement star inserted first in the slots (placeTitleIcons puts the last slot next to the title). completecheck_test. In game: not run |
| R3579-1 | Finished quest icon opacity 87 % | Extras.lua DONE_ICON_ALPHA 0.87 (Icon opacity below it is kept). completecheck_test |
| R3580-1 | Mark-done check hidden while current steps are collapsed | Rows.lua: the collapsed spacer row (often the pooled current-step row) hides its Done button, as it does Info. upcoming_test (pool reuse simulated; fails without the fix). In game: not run |
| R3581-1 | RXP Tracker commands typed after /qt; /rt removed; no /ao mentions | Slash.lua ns.runCommand (no slash registration); Tracker/Core.lua /qt passes unknown commands on; Core.lua no-RestedXP branch answers guide commands; texts updated. qtslash_test. In game: not run |
| R3582-1 | /qt help lists all commands (config, quests, sort, help, steps were missing) | Tracker/Core.lua QT_HELP + printHelp, help no longer routed to the guide only; Slash.lua steps line. qtslash_test. In game: not run |
| R3583-1 | /qt debug in a themed window with "Copy all and close"; /qt focus removed; debug hidden from help | Tracker/DebugWindow.lua (theme kit; select all, closes on Ctrl+C; CopyToClipboard is restricted so not called); Core.lua debugLines collector. debugwindow_test, qtslash_test, smoke2 /qt debug run. In game: not run |
| R3584-1 | Orphaned quests cleanup in Themes & guide (Forever style), hover Abandon per quest and Cleanup all | Objectives/Settings.lua orphans (RXP.GetOrphanedQuests, isHidden off while read) and abandonOrphans (re-checked, one per 0.2 s, RestedXP select/SetAbandonQuest/AbandonQuest); Config.lua buildOrphans (two-click confirm, refreshed each second on the page). orphans_test, orphanabandon_test. In game: not run |
| R3584-2 | Questie reputation rewards in quest tooltips and the Prerequisite Journal | Questie.lua questieRepRewards (QuestieReputation.GetReputationReward, else reputationReward field; cached) and questRepTotals; Extras.lua questRep in addRewards and title suffix; Prereqs.lua Reputation line. questierep_test (module, raw), rewardvendor_test, journal_render_test. In game: not run |
| R3585-1 | Remove Questie reputation rewards (R3584-2); keep orphaned quests (R3584-1) | Questie.lua, Extras.lua, Prereqs.lua identical to 3.5.83; questierep_test removed, rep checks dropped. Full suite. In game: not run |
| R3586-1 | Orphans = not used by current guide (from your step) or any later guide; previous guides do not count | Prereqs.lua api.questsAhead (routes after the current guide, other route from its level, next chain; every element questId/ids; cached per guide and step); Settings.lua orphans from the quest log (RestedXP list only as fallback). orphanahead_test, journal_render_test. In game: not run |
| R3587-1 | Orphaned quests list identical to RestedXP's (supersedes R3586-1) | Settings.lua and Prereqs.lua as in 3.5.85 (RXP.GetOrphanedQuests); Config.lua note names the list. orphans_test, orphanabandon_test. In game: not run |
| R3588-1 | Orphaned quests on their own settings page under Themes & guide | Config.lua page("orphans", "guide") after the guide page (no reset: no Defaults). orphans_test (page order and group). In game: not run |
| R3589-1 | Orphaned quest rows coloured by difficulty | Config.lua questDifficultyColor (GetQuestDifficultyColor, else level difference with GetQuestGreenRange); player level in the refresh signature. orphans_test. In game: not run |
| R3590-1 | Orphaned quests sorted by level, low first | Config.lua buildOrphans sorts by level then title. orphans_test. In game: not run |
| R3590-2 | /qt orphan opens the Orphaned quests page | Tracker/Core.lua orphan/orphans -> openConfigTab("orphans") (message without RestedXP); QT_HELP line. qtslash_test, orphans_test. In game: not run |
| R3591-1 | Zone shown left of each orphaned quest | Settings.lua logZones (quest log header per quest) on each orphan; Config.lua zone column (30 % of the row, 110-190 px). orphans_test, orphanabandon_test. In game: not run |
| R3592-1 | Orphaned quests sort by difficulty, name or zone, with a reverse checkbox | Config.lua Sort by choice + Reverse check on the orphans page (db.orphanSort, db.orphanReverse; DEFAULTS level/false; Defaults button); buildOrphans sort, settings in its refresh signature. orphans_test. In game: not run |
| R100-1 | Release 1.0 on GitHub (imfleek/RXPForeverTracker); earlier builds marked pre-release alpha | Repo layout = addon folder; .pkgmeta (package-as, manual-changelog, ignore REQUIREMENTS/tests/.github); .github/workflows/release.yml (BigWigsMods/packager@v2 on v* tags); tests/ committed. |
| R100-2 | Release notes list only that version's changelog section | release.yml: awk cuts the "## <version>" section of CHANGELOG.md into the package before the packager runs (whole file as fallback, with a warning). |
| R100-3 | Release zip always named RXPForeverTracker.zip | release.yml: packager -n "RXPForeverTracker:{project-version}" (dry run: RXPForeverTracker.zip). |
| R101-1 | README: _forever_ path, "Settings: /qt" header, commands in tables with descriptions, no Layout section | README.md. |
| R100-4 | Release notes also include the major release's entry (## <major>.0, e.g. 1.0 for 1.x) | release.yml: this version's section, then a rule and the major's section (not repeated for the .0 release itself). Simulated for 1.0.1 and 1.0. |
