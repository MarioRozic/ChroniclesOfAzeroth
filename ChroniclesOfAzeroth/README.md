# Chronicles of Azeroth

An RPG companion for **World of Warcraft: Forever**: a travel journal, a character
profile and a chronicle of everything you really did on your journey. It never
plays the game for you and never invents events.

Version 0.1.0 (Phase 1).

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
- `/coa journal`, `/coa profile`, `/coa history`, `/coa exploration` open a chapter.
- `/coa scale 0.9`, `/coa resetpos`, `/coa minimap off|on`
- `/coa status` prints the client version, interface number and any event the
  client refused to register.
- `/coa reset confirm` erases this character's chronicle.

Drag the title to move the window, drag the bottom-right grip to resize it,
press Escape to close it.

## What it records (Phase 1)

| Event | Source |
|---|---|
| Chronicle start, login sessions | `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD` |
| Zones visited, first visit, visit count | `ZONE_CHANGED_NEW_AREA`, `GetRealZoneText`, `C_Map` |
| Dungeons/instances entered | `IsInInstance`, `GetInstanceInfo` |
| Level ups | `PLAYER_LEVEL_UP` |
| Quests completed (with title) | `QUEST_TURNED_IN`, `QUEST_COMPLETE` |
| Deaths | `PLAYER_DEAD` |
| Time played | `TIME_PLAYED_MSG` (requested once per session, when you open the profile) |

Data is saved per character (`Name-Realm`) in
`WTF/Account/<ACCOUNT>/SavedVariables/ChroniclesOfAzeroth.lua`.

## Architecture

```
Core/      Init (namespace, modules, message bus), Util, Compat (all client API
           access), Database (SavedVariables, defaults, migrations), Events
           (single event frame), Bootstrap (startup + slash commands)
Modules/   EventFeed (feed storage + entry kinds), Character, Tracker, Journal
UI/        Theme, Widgets, MainFrame, MinimapButton, Pages/*
```

To add a feature: create a module with `CoA:NewModule("Name")`, register events
with `CoA:RegisterEvent(event, module, "Method")`, record facts with
`CoA.Feed:Add(kind, data)` after `CoA.Feed:RegisterKind(kind, {...})`, and add a
page with `CoA.UI:RegisterPage(key, {...})`. Schema changes go in
`Core/Database.lua` as a new `MIGRATIONS[n]` entry.
