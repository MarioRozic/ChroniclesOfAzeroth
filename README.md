<p align="center">
  <!-- SCREENSHOT: a wide in-game shot of the open book (Character page works best) -->
  <img src="docs/screenshots/hero.png" alt="Chronicles of Azeroth in game" width="820">
</p>

<h1 align="center">Chronicles of Azeroth</h1>

<p align="center"><b>Your leveling journey, written down like an RPG chronicle.</b><br>
A journal that writes itself, a character profile, 45 milestones with titles, challenges you choose,<br>
and a way to compare chronicles with friends. Made for <b>World of Warcraft: Forever</b>.</p>

<p align="center">
  <a href="https://www.curseforge.com/wow/addons/chronicles-of-azeroth">CurseForge</a> ·
  <a href="https://addons.wago.io/addons/chronicles-of-azeroth">Wago</a> ·
  <a href="https://www.wowinterface.com/downloads/info00000">WoWInterface</a> ·
  <a href="../../issues/new/choose">Report a bug or suggest an idea</a>
</p>

---

## What it does

Chronicles of Azeroth watches what you actually do (zones, quests, kills, rares,
bosses, dungeons, level ups, deaths) and turns it into a book you can open with
`/coa`. It never plays the game for you and never makes anything up.

- **Adventure Journal**: an auto-written diary of your journey, day by day.
  <!-- SCREENSHOT: docs/screenshots/journal.png -->
- **Character profile**: your title, tallies and the story so far.
  <!-- SCREENSHOT: docs/screenshots/character.png -->
- **45 milestones with titles**: from *First Steps* to *Champion of Azeroth*.
  Earn titles like *the Explorer*, *Tyrantsbane* or *the Unbroken*.
  <!-- SCREENSHOT: docs/screenshots/milestones.png -->
- **Challenges**: accept up to five at a time (19 in six groups, like *Survivor*,
  *Rare Tracker* or *Shoulder to Shoulder*), each with its own notification.
  <!-- SCREENSHOT or GIF: docs/screenshots/challenge-complete.gif -->
- **Exploration**: every region and hidden place you have uncovered.
- **Event history**: a full log of what happened and when.
- **Fellows**: inspect a friend who also uses the addon and compare chronicles
  side by side. **Brag** posts your journey to party or guild in one click.
  <!-- SCREENSHOT: docs/screenshots/fellows.png -->

It looks and feels like part of the game: a Quest Log style open book with
parchment pages, red buttons and chapter tabs.

## Install

**With an addon manager (recommended):** search for *Chronicles of Azeroth* in
the CurseForge app or WowUp/Wago and pick the WoW Forever install.

**By hand:**

1. Download the latest zip from [Releases](../../releases).
2. Unzip it into your Forever AddOns folder so you get
   `_forever_/Interface/AddOns/ChroniclesOfAzeroth/ChroniclesOfAzeroth.toc`
   - Windows: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`
   - macOS: `/Applications/World of Warcraft/_forever_/Interface/AddOns/`
3. Start the game and type `/coa`.

## Commands

| Command | What it does |
|---|---|
| `/coa` | Open or close the chronicle (or click the minimap book) |
| `/coa journal`, `profile`, `challenges`, `history`, `exploration`, `milestones` | Open a chapter |
| `/coa brag party` / `guild` / `say` | Post a summary of your journey |
| `/coa inspect` | Read your target's chronicle (they need the addon too) |
| `/coa announce guild on` | Announce new milestones (off by default, rate-limited) |
| `/coa feedback` | Get the link to report a bug or suggest an idea |
| `/coa help` | Every command |

## Privacy and chat etiquette

Announcements are **off by default** and rate-limited (one line a minute, five
an hour, never in combat). Inspecting only shares your title, totals and
milestones. Your journal and location are never shared, and you can turn
inspecting off under *Fellows > Sharing*.

## Ideas and feedback

This addon grows with its players. Got an idea for a milestone, a challenge, or
something the journal should notice?

- 🏅 [Suggest a milestone](../../issues/new?template=milestone_idea.yml)
- ⚔️ [Suggest a challenge](../../issues/new?template=challenge_idea.yml)
- 🐞 [Report a bug](../../issues/new?template=bug_report.yml)
- 💬 [Chat about it in Discussions](../../discussions)

In game, `/coa feedback` gives you the link. One rule for new milestones: the
addon has to be able to *see* it happen (it only uses events the game tells
addons about), so describe what the player does and we'll work out whether it
can be detected.

## Compatibility

| | |
|---|---|
| Game | World of Warcraft: Forever 1.60.x |
| Interface | 16001 |
| Libraries | none |

## For developers

The addon lives in [`ChroniclesOfAzeroth/`](ChroniclesOfAzeroth). Its own
[README](ChroniclesOfAzeroth/README.md) covers the architecture, every event it
listens to and how to add a module, milestone or challenge. Pull requests are
welcome; please open an issue first for anything big.

Releases are built by [BigWigsMods/packager](https://github.com/BigWigsMods/packager)
when a `v*` tag is pushed (see `.github/workflows/release.yml`).

## License

[MIT](LICENSE) © 2026 Mara
