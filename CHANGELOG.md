# Changelog

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
