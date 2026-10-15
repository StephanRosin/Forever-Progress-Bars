**Summary**

Your professions, secondary skills, reputations and experience as bars, in six looks: Forever, Blizzard's bar, Rune stone, Gems, Hairline and Forge. In a row or in columns, scaled as you like, shareable as a string. Click a bar to open the profession.

---

# Forever Progress Bars

Everything you level, in one place: two primary professions, two secondary skills, four reputations of your choice and an experience bar with your level, for **WoW: Forever**. English, Deutsch, Español, Français.

## Looks
Six looks, for the progress bars and the XP bar each on its own:
- **Forever**, the plain look: the rim of your choice (none, flat in a colour, or gold shaded like the minimap's), its width, the background's colour and opacity, and if you like a **gold marker** where the fill ends.
- **Blizzard**: Blizzard's own experience bar art, frame and dividers.
- **Rune stone**: a carved slab, the fill glowing arcane, runes that light up at 25, 50, 75 and 100 %.
- **Gems**: twenty amethysts in gold settings on a chain; the one being filled is cut where you are.
- **Hairline**: three pixels, no frame, small text.
- **Forge**: a forged iron frame with rivets, molten metal glowing hottest at its end.

The progress bars keep their colours in every look: each profession its own, each reputation its standing's.

## Professions and skills
- Two primary professions on the left, two secondary skills on the right (First Aid and Cooking by default), each with its icon, name and rank.
- Your rank in the middle of each profession bar: Apprentice, Journeyman, Expert, Artisan, Master (can be switched off and moved up or down).
- Fishing and Riding are hidden by default; every skill can be shown or hidden in the options.
- Coloured per profession: flask green for Alchemy, arcane purple for Enchanting, bolt-of-cloth blue for Tailoring, and so on.
- **Click a bar to open the profession**, the same way Blizzard's own profession tabs do. Click again to close it. Gathering skills without a window stay unclickable.
- The tooltip shows rank, points to the next cap and any bonus.
- Works in every client language: professions are recognised by their spells, not by English names. Profession names, ranks and standings also follow the language you pick in the options.

## Reputation
- A second row with up to four factions, lined up under the profession bars.
- Colours from the game's own reputation colours, and the standing ("Friendly", "Honored", ...) in the middle of the bar.
- **Left-click a reputation bar to pick another faction** right there; right-click opens the reputation tab.

## Experience bar
- In any of the six looks, with **colours of your own per look** (or the look's own), its own height, width, background and segments: none of the progress bars' settings touch it.
- Above the professions, between professions and reputation, at the bottom, or **anywhere on the screen**.
- **The level** as text, as a badge, or hidden. As text it has its own place (above, in or below the bar; left, middle or right), offset, font, size and colour; in Forever it can sit on a plate like the quest log's title. As a badge it sits at any point of the bar or rides on the end of the fill.
- **Badges**: Classic, Gold, Class colour or the number alone, hand-drawn gold badges (crest, laurel wreath, wings), a **rank medal** whose ornaments grow every ten levels, a rune stone, an amethyst, an iron shield, two gold rings from Blizzard's own art, or **the one matching the bar's look**. The number in gold, white or your class colour; font, size, outline and padding adjustable.
- **The numbers** ("730 / 23200 (3%)", or the percentage, or none) with their own place, offset, font, size and colour.
- Rested experience shows ahead of the fill; the tooltip gives experience, progress, what is left to the next level and rested experience.
- **Extra lines**, each on its own and off by default: time this level, time this session, XP per hour, next level in ~1h 20m, quests completed on this character, and your rested bonus (only while you have one). Every line hangs on the XP bar at a place of your choice and moves by pixels; one font, size and colour for all of them (by default the numbers').
- Room above the bar is kept only while a text sits there.
- Hidden at the maximum level. While it is on, Blizzard's experience bar is hidden.

## Background
- An optional background behind the progress bars, sized to cover exactly what is shown (the reputation row only while it has bars).
- Any colour and opacity, padding, and a flat or **gold** border from 1 to 8 pixels, **with or without the background**.

## Layout
- **In a row** (professions side by side, reputation below), **in two columns** (professions left, reputation right) or **in one column** (professions, then reputation), with a bar width of your choice for the columns.
- Space between bars side by side and one under the other, each on its own.
- Switch professions or reputation on or off; the rest closes up.
- **Hide in combat or in a group**, the bars and the XP bar each on their own (safe in combat: the game hides them itself).
- **Scale everything together** from 50 to 200 %.
- Position from the screen's centre or left edge, and from its top edge or centre, so it lands in the same place on other resolutions.
- The strip starts at the top of the screen, 60 % of the screen wide (at most 1180), so it fits small screens and large UI scales too, and **locked** (click-through). Right-click the minimap button or type `/fpb unlock` to drag it somewhere else, or set position and width exactly in the options.
- Bar height, text height, the space between text and bar, segment width, label font size and icon size are all adjustable, as are the colour and opacity of the bars' empty part.

## Options
- Its own options window in the style of Forever Unit Frames, opened from the **minimap button** or with `/fpb`, in two groups: **Progress bars** (show & position, bars, professions, reputation, background) and **XP bar** (bar & look, texts, badge, extra lines). Each part is switched on or off under General; switched off, its pages leave the menu.
- Also listed in Blizzard's **addon compartment** next to the minimap: left-click opens the options, right-click locks or unlocks the strip.
- **Profiles**: save your layout under a name and share it between characters.
- **Presets** in the profile list: "Classic" (one row) and "Column with XP bar". They are read-only (changes last until the next reload); "Save as..." turns one into a profile of your own. Your reputations, hidden skills, lock and minimap button come along.
- **Export and import**: your whole profile as a text string to pass on; paste one to take it over. Imports are only read as settings, never run as code.
- **What's new**: after an update, a short window says what changed; `/fpb news` shows it again.
- Language: follows the game; a dropdown in the options window picks another one, and the change applies at once.

## Commands
`/fpb` (options), `/fpb lock`, `/fpb unlock`, `/fpb status`, `/fpb news`

## Notes
- Made for WoW: Forever.
- Fonts: the game's own, plus every font another addon registers with LibSharedMedia.
- The translations were not written by native speakers: corrections are very welcome on the issue tracker.
- Bug reports and ideas are welcome on the project's issue tracker. `/fpb status` prints what helps with a report.
