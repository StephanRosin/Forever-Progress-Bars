# Forever Progress Bars

Two primary professions, two secondary skills and four reputations as bars,
and an experience bar with your level, for WoW: Forever. Six looks (Forever,
Blizzard, Rune stone, Gems, Hairline, Forge) for the progress bars and the XP
bar each on its own. Its own options window (minimap button or `/fpb`),
profiles, What's new after an update (`/fpb news`), and English, German,
Spanish and French.

The full feature list is in [docs/curseforge/description.md](docs/curseforge/description.md).

## Development

    tests/run                    # Lua 5.1, as in the game
    ./install "<WoW>/_classic_beta_/Interface/AddOns"
    tools/package                # dist/ForeverProgressBars-<version>.zip
    tools/make_badges            # tools/badges and tools/art (SVG) to Media/*.tga
    tools/release release "<changelog>"   # bump ## Version first
