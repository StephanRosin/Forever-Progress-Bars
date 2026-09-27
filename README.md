# Forever Progress Bars

Two primary professions, two secondary skills and four reputations as bars,
with the character level in a box in the middle, for WoW: Forever. Its own
options window (minimap button or `/fpb`),
profiles, and English, German, Spanish and French.

The full feature list is in [docs/curseforge/description.md](docs/curseforge/description.md).

## Development

    tests/run                    # Lua 5.1, as in the game
    ./install "<WoW>/_classic_beta_/Interface/AddOns"
    tools/package                # dist/ForeverProgressBars-<version>.zip
    tools/release release "<changelog>"   # bump ## Version first
