# Changelog

## v3.11.09-13x8.13

- Replaces the generated HD keyboard/mouse inventory background with the hand-authored `Background_Expanded2_13x8` sprite.
- Stops regenerating the 13x8 HD background during install, so the manual art is preserved instead of being overwritten by scripted pixel moves.
- Adds validation that installed `background_expanded2_13x8.sprite` and `.lowend.sprite` exactly match the overlay assets.

## v3.11.09-13x8.12

- Moves centered equipment background art using the real visual frame coordinates instead of the interactive slot rectangles, fixing clipped/misaligned borders around the head, torso, and belt frames.
- Keeps the duplicate-frame cleanup and shifted right-side frame restore from `v3.11.09-13x8.11`.

## v3.11.09-13x8.11

- Copies the centered head, torso, and belt background slots with an 8px padded border area so their visible frames are not clipped.
- Clears the old duplicated neck, left ring, left arm, and feet background frames left behind inside the inserted HD band while preserving their shifted final positions.
- Tightens the sprite regression test to check centered padded frames and reject duplicated right-side equipment frames.

## v3.11.09-13x8.10

- Smooths the generated HD equipment background by extending the adjacent original background through the added 294px band instead of filling the whole band with a separate stone texture.
- Keeps the centered head, torso, and belt background slots from `v3.11.09-13x8.9`.
- Extends the sprite regression test to catch the visible vertical insert band in the upper equipment area.

## v3.11.09-13x8.9

- Moves the generated HD background art for the head, torso, and belt slots to the same centered positions as the interactive equipment slots.
- Fills the old head, torso, and belt background slots with matching stone texture so duplicate frames are not left behind.
- Adds a sprite-level regression test for centered equipment background slots.

## v3.11.09-13x8.8

- Centers the HD head, torso, and belt equipment slots inside the visible 13x8 panel while keeping the inventory grid origin unchanged for AutoStocker.
- Fixes the generated `Background_Expanded2_13x8` top frame band so the added center width extends the horizontal frame instead of replacing it with stone fill.
- Keeps the AutoStocker DLL coordinate patch from `v3.11.09-13x8.7`.

## v3.11.09-13x8.7

- Restores the visible HD keyboard/mouse layout: the 13x8 frame expands left so the added columns and equipment slots remain visible on 16:9.
- Adds an AutoStocker DLL coordinate patch that changes the inventory X offset from `1140` to `1434`, matching the left-expanded panel and avoiding mouse drift.
- Adds validation for the patched AutoStocker coordinate table.

## v3.11.09-13x8.6

- Changes the HD keyboard/mouse layout to an AutoStocker-compatible anchor: the original inventory grid origin and height are preserved, and the extra three columns expand to the right.
- Keeps the generated 13x8 `Background_Expanded2_13x8` art and 294px offsets for the close button, hinge, and right-side equipment slots.
- Replaces the left-expanded layout constant test with an AutoStocker-compatible layout test.

## v3.11.09-13x8.5

- Fixes the HD keyboard/mouse inventory anchoring for auto-stocking tools: the original `$RightPanelRectI` right edge, top, and bottom are preserved, and the extra three columns expand to the left.
- Keeps the generated 13x8 `Background_Expanded2_13x8` art and offsets the close button, hinge, and right-side equipment slots by 294px so their screen positions stay aligned.
- Adds a focused layout-constant test for the left-expanded HD inventory contract.

## v3.11.09-13x8.4

- Restores the HD keyboard/mouse inventory to the original EasternSunLAN UI layout.
- Keeps the inventory at 13x8 while using the original `Background_Expanded2`, original panel rect, original click catcher, original weapon-swap tab positions, and original equipment slot positions.
- Keeps the broader D2RLAN expanded template coverage from previous releases so the launcher toggle should not revert the active layout to an older template.

## v3.11.09-13x8.3

- Changes the HD keyboard/mouse inventory to a roomier equipment layout.
- Keeps the inventory at 13x8, but moves the grid slightly lower and restores more vertical spacing for weapon, armor, gloves, boots, rings, belt, helm, and amulet slots.
- Moves the HD weapon-swap tab widgets to match the roomier equipment area.

## v3.11.09-13x8.2

- Adds the 13x8 HD inventory background sprite overlay from the D2RMM ExpandedInventory source.
- Reworks HD original, HD weapon-swap, controller original, and controller weapon-swap layouts to use the official 13x8 coordinates.
- Adds `_profilelv.json` support and stricter validation for panel rects, sprite filenames, and grid positions.
- Fixes the v3.11.09-13x8.1 issue where `inventory.txt` and `cellCount` were 13x8, but the visible inventory background could still look like 10 columns.

## v3.11.09-13x8.1

- Added a PowerShell installer for EasternSunLAN 3.11.09.
- Changes the player inventory grid from 10x8 to 13x8 for the seven base classes and their `2` variants.
- Updates HD, legacy, controller, and D2RLAN expanded inventory layouts.
- Preserves user settings while setting `ExpandedInventory=true` when `MyUserSettings.json` exists.
- Adds validation and uninstall helpers.
