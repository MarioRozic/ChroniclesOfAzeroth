# Chronicles of Azeroth

An RPG companion for **World of Warcraft: Forever**: a travel journal, a character
profile and a chronicle of everything you really did on your journey. It never
plays the game for you and never invents events.

Version 0.5.0 (sharing: announcements, Brag and Fellows).

## Client compatibility

| | |
|---|---|
| Target client | WoW Forever 1.60.x (game type `forever` / `camelot`) |
| Interface (.toc) | `16001` |
| Code base | Mainline (Midnight 12.1.x), **not** the 1.12 Vanilla client |
| Lua | 5.1 (WoW's embedded Lua) |
| Libraries | none |

## Install

1. Close WoW (or be ready to `/reload`).
2. Copy the `ChroniclesOfAzeroth` folder into your Forever AddOns folder:
   - Windows: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`
   - macOS: `/Applications/World of Warcraft/_forever_/Interface/AddOns/`
   The folder name must stay exactly `ChroniclesOfAzeroth`, and the `.toc` must
   be directly inside it (not in a nested folder).
3. Start WoW Forever. On the character screen, open **AddOns** and make sure
   *Chronicles of Azeroth* is enabled. If it says "out of date" after a Forever
   patch, tick **Load out of date AddOns**.

## Use

- `/coa` or `/chronicles` opens the tome. The minimap book icon and the addons
  compartment button by the minimap do the same (right-click opens Event History).
- `/coa journal`, `/coa profile`, `/coa challenges`, `/coa history`, `/coa exploration` open a chapter.
- `/coa sound on|off` turns notification sounds on or off.
- `/coa scale 0.9`, `/coa resetpos`, `/coa minimap off|on`
- `/coa milestones` opens the Milestones chapter; `/coa toast` previews a
  milestone notification.
- `/coa status` prints the client version, interface number, your tallies, which
  kill sources are active, and any event the client refused to register.
- `/coa reset confirm` erases this character's chronicle.

The window is laid out like Blizzard's Quest Log: an open book of two parchment
pages, with a list on the left page and the chosen entry on the right, red buttons
under the book (Accept, Abandon Challenge, Change Title, Close) and the chapters as
tabs along the bottom. Drag the frame to move it, drag the
bottom-right grip to resize it, and close it with the X or Escape.

## Challenges

Open the Challenges tab and press **Accept** on up to five challenges at once.
Progress counts only from the moment you accept, completing one writes it into
the chronicle and shows a notification, and every challenge can be taken again.
Survivor fails if you die. There are 19 challenges in six groups (Exploration,
Combat, Dungeons, Collection, Social, General), defined in `Data/Challenges.lua`.
Only deeds the addon can observe reliably are used. "Courtesy of the Road" needs a
player targeted when you `/wave`.

Notifications never appear during combat: they wait until combat ends.

## Sharing

- **Announcements** (off by default): turn them on in Fellows > Sharing, or with
  `/coa announce guild on` / `/coa announce party on`. Milestones earned close
  together share one line; at most one line a minute and five an hour per channel;
  nothing during combat or a boss fight; never for milestones recorded quietly at login.
- **Brag**: the Brag button on the Character page (your journey) and on an earned
  milestone posts one line to Say, Party or Guild, picked from a small menu.
  `/coa brag guild` does the same from chat.
- **Fellows**: target a player who also uses the addon and press Inspect Target
  (or `/coa inspect`, or "View Chronicle" in the player's right-click menu). Their
  title, totals and milestones are compared with yours. It uses hidden whispered
  addon messages (`C_ChatInfo.SendAddonMessage`, prefix `CoAChron`), cut into
  240-byte pieces, paced and retried when throttled, and never sent in combat or
  an encounter. You can turn inspecting off under Fellows > Sharing; your journal
  and location are never shared.

## What it records

| Event | Source |
|---|---|
| Chronicle start, login sessions | `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD` |
| Zones visited, first visit, visit count | `ZONE_CHANGED_NEW_AREA`, `GetRealZoneText`, `C_Map` |
| Dungeons/instances entered | `IsInInstance`, `GetInstanceInfo` |
| Level ups | `PLAYER_LEVEL_UP` |
| Quests completed (with title) | `QUEST_TURNED_IN`, `QUEST_COMPLETE` |
| Deaths | `PLAYER_DEAD` |
| Time played | `TIME_PLAYED_MSG` (requested once per session, when you open the profile) |
| Named places, hidden places uncovered | `ZONE_CHANGED`, `MAP_EXPLORATION_UPDATED`, `C_MapExplorationInfo` |
| Enemies defeated (open world) | `PARTY_KILL` (your or your pet's killing blow), `UNIT_DIED` for a creature you were fighting and that was not tapped by others |
| Elites, rares, creature types | `UnitClassification`, `UnitCreatureType` on your target, mouseover and nameplates |
| Bosses defeated | `ENCOUNTER_END` with success |
| Dungeons completed | final Encounter Journal boss defeated, all bosses defeated, or `LFG_COMPLETION_REWARD` |
| Milestones | 45 definitions in `Data/Achievements.lua`, judged only on the data above |
| Challenges | the deeds above, plus `IsInGroup` for group challenges and a `hooksecurefunc` hook on `DoEmote` for /wave |

Kills inside instances are not counted: Forever hides creature identity from
addons there. Milestones earned from data recorded before they existed are
unlocked quietly at login, with one summary notice.

Data is saved per character (`Name-Realm`) in
`WTF/Account/<ACCOUNT>/SavedVariables/ChroniclesOfAzeroth.lua`.

## Architecture

```
Core/      Init (namespace, modules, message bus), Util, Compat (all client API
           access), Database (SavedVariables, defaults, migrations), Events
           (single event frame), Bootstrap (startup + slash commands)
Modules/   EventFeed (feed storage + entry kinds), Character, Tracker, Journal,
           Combat (kills, rares, bosses, dungeon runs), Achievements, Challenges
Data/      Achievements (milestones), Challenges (challenge definitions)
UI/        Theme, Widgets, MainFrame, Toast, MinimapButton, Pages/*
```

To add a feature: create a module with `CoA:NewModule("Name")`, register events
with `CoA:RegisterEvent(event, module, "Method")`, record facts with
`CoA.Feed:Add(kind, data)` after `CoA.Feed:RegisterKind(kind, {...})`, announce
deeds for challenges with `CoA:Fire("DEED", kind, ctx)`, and add a
page with `CoA.UI:RegisterPage(key, {...})`. Schema changes go in
`Core/Database.lua` as a new `MIGRATIONS[n]` entry.
