# Visual Assets

Game pieces, not illustrations. Priority order for every asset: gameplay
readability, silhouette, clear state, color, iconography, decoration.

**Status:** no assets yet. Ships, sea and wind indicator are tinted blocks and
vector lines. The first asset family will be terrain (Milestone M2).

## Workflow (D-024)

1. **Spec.** The asset agent writes the spec below for the asset family: purpose, TTS object type, size in inches, aspect ratio, pixel size, transparency, states, and how it must read at normal table zoom.
2. **Prompts.** One prompt per asset, all built from the family's shared style block so variants match. Saved next to the asset as `assets/<family>/<id>.prompt.md`.
3. **Generate.** The owner runs the prompts through an image generator and drops results in `assets/<family>/incoming/`.
4. **Review.** The agent checks each image against the spec (silhouette, orientation, scale, edges, transparency, consistency with approved assets) and either approves it or writes a revised prompt.
5. **Prepare.** Approved images are cropped, resized and given transparency as needed, then saved as `assets/<family>/<id>_v<n>.png`.
6. **Upload.** The owner uploads them to Steam Cloud (see below) and pastes the URLs; they go in `data/assets.lua`.
7. **Integrate and test.** The TTS agent uses them; the owner checks in TTS.
8. **Record.** The manifest row is marked Approved with the version and URL.

## How images reach TTS (D-025)

TTS objects never embed images. A save (and a Workshop mod, which is just a
published save) stores a **URL** for each image, and every player's TTS
downloads and caches it. Published Workshop mods almost all use **Steam
Cloud** URLs (`https://steamusercontent-a.akamaihd.net/ugc/...`), which is
TTS's built-in hosting:

- **Modding > Cloud Manager > Upload** puts a file in the owner's Steam Cloud and gives a permanent public URL. (The Custom Image dialog's "Cloud" option does the same for a single file.)
- Those URLs keep working for everyone after the mod is published to the Workshop, as long as the file is **not deleted** from Cloud Manager.
- During development the mod can point at local files (`file:///C:/...`) so the owner can test without uploading; those only work on the owner's machine, so they are swapped for Cloud URLs before publishing.

So the plan: the repo keeps the source PNGs; `data/assets.lua` maps each asset
ID to its URL (local path while testing, Steam Cloud URL once approved); the
script spawns tokens and tiles from that table. No agent can upload to Steam
Cloud, so uploading is one owner step per approved batch.

## Style

To be set with the first family (terrain) and approved by the owner. Every
later family must reuse its camera angle, lighting, palette, edge treatment and
scale conventions. Fixed conventions already in the mod:

- 1 TTS unit = 1 inch. Sea is 48" x 48", color `{0.11, 0.29, 0.42}`.
- Side tints: Red `{0.72, 0.16, 0.16}`, Blue `{0.16, 0.36, 0.75}`.
- Ship bases: 1st/2nd Rate 50x100 mm, 3rd/4th 40x80 mm, 5th/Frigate 30x70 mm. Bow is +z at heading 0.
- Vector-line markings on bases (attitude X, bow arrow) must stay visible over any ship art.

## Spec template

```
Asset ID / Name / Family
Purpose (what the player needs to read from it)
TTS type (Custom_Tile, Custom_Token, card, UI image, board)
Size on table (inches) / Aspect ratio / Pixel size
Transparent background? / States or variants
Script interaction (spawned by script? clickable? state swaps?)
Readability check (what must be clear at normal zoom)
Style block (shared by the family)
```

## Manifest

| Asset ID | Name | Type | Purpose | Size / aspect | Transparent | TTS usage | Status | Approved version | URL | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | | | |
