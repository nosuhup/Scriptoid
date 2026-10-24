# Scriptoid

A configurable Roblox client-side movement and camera utility collection written in Luau.

Scriptoid currently contains two separate scripts:

- **`seroid.lua`** — movement, jump, dash, and camera field-of-view controls powered by VibeUI.
- **`curvoid.lua`** — a standalone camera utility with a fast, eased backward turn and return animation.

> [!IMPORTANT]
> These scripts modify client-side behavior. Compatibility depends on the Roblox experience, client environment, avatar rig, and external dependencies. Use them only in experiences you own or in environments where these modifications are explicitly permitted. This project is not affiliated with Roblox.

## Contents

- [Scripts at a glance](#scripts-at-a-glance)
- [Features](#features)
- [Controls](#controls)
- [Requirements](#requirements)
- [Setup](#setup)
- [Configuration and cleanup](#configuration-and-cleanup)
- [Troubleshooting](#troubleshooting)
- [Compatibility and limitations](#compatibility-and-limitations)
- [Development](#development)
- [License](#license)

## Scripts at a glance

| File | Purpose | UI dependency |
|---|---|---|
| `seroid.lua` | Movement tuning, jump controls, dash options, and camera FOV | [VibeUI](https://pages.sirmemegithub.com/VibeUI/) |
| `curvoid.lua` | Smooth backward camera turn, return animation, upward camera action, and motion settings | Uses VibeUI for its controls UI; check the source for current loader behavior |

The scripts are independent. Run only the one you intend to test. **The `seroid.lua` source is intentionally unchanged by the repository documentation and naming update.**

## Features

### `seroid.lua`

- **Movement speed:** adjustable speed slider and presets.
- **Movement feel:** smoothing strength, grounded-only behavior, and vertical-velocity handling.
- **Jump controls:** enable/disable jump boost and choose Power or Height mode.
- **Dash options:** configurable dash cooldown, dash duration, target range, and backstab offset.
- **Camera FOV:** toggle custom field of view, use presets, and restore the captured value.
- **Profiles:** save/load a quick profile and reset the main controls.
- **UI and notifications:** VibeUI tabs, controls, status information, and notifications.
- **Cleanup:** tracks event connections and attempts to restore captured jump and camera settings when unloaded.

### `curvoid.lua`

- **F — backward turn:** a fast, eased 180° camera turn followed by a return animation.
- **R — upward camera action:** angle is adjustable.
- **Motion tuning:** separate turn, hold, and return durations.
- **Angle and cooldown controls:** adjustable backward angle and F cooldown.
- **Hotkey settings:** enable/disable hotkeys and rebind actions.
- **Quick actions:** reset settings and cancel the active camera motion.
- **Cleanup:** cancels active tweens and attempts to restore the prior camera mode.

Check the current source for exact defaults and behavior; the UI and scripts may evolve independently.

## Controls

### `seroid.lua` defaults

| Action | Default |
|---|---|
| Open/close UI | Right Ctrl |
| Toggle speed | Left Ctrl (toggle binding on the speed control) |
| Toggle dash/backstab system | H |
| Straight dash action | Q |
| Backstab/flank action | R |
| Speed | 37 studs/s |
| Jump boost | Off |
| Custom FOV | Off |
| Dash cooldown | 3.9 seconds |

Some bindings are configured both in the UI and in the script. The behavior of UI keybinds can vary with the installed VibeUI version.

### `curvoid.lua` defaults

| Action | Default |
|---|---|
| Backward camera turn | F |
| Upward camera action | R |
| Open/close UI | Right Ctrl |
| Backward turn angle | 180° |
| Turn duration | 0.09 seconds |
| Hold duration | 0.05 seconds |
| Return duration | 0.09 seconds |
| F cooldown | 2 seconds |

Curvoid's default turn, hold, and return sequence is approximately 0.23 seconds. Frame rate, camera mode, and other local scripts can affect the perceived result.

## Requirements

### For `seroid.lua`

- A compatible client-side Luau environment.
- Access to the [VibeUI library](https://pages.sirmemegithub.com/VibeUI/).
- A local player character with a `Humanoid` and a suitable root part for movement controls.
- An environment that supports the Roblox APIs used by the script.

### For `curvoid.lua`

- A compatible client-side Luau environment.
- The UI library and loader behavior required by the current source.
- Permission to modify the camera in the experience being tested.

External dependencies may become unavailable or change without notice. Review their source and license before relying on them.

## Setup

1. Read the source file you intend to use.
2. Review the dependency and API requirements above.
3. Confirm that the experience permits the intended client-side modifications.
4. Run the script in an isolated test experience first.
5. Test the controls individually and verify that the camera, movement, and jump settings return to their expected state after unloading.

Do not run unknown code simply because it is hosted on GitHub. Review remote dependencies and avoid sharing authentication tokens, account credentials, or private executor logs.

## Configuration and cleanup

- Use each script's UI to adjust supported settings.
- Start with conservative values and change one setting at a time.
- Use the reset controls if a configuration produces unexpected behavior.
- Unload the script before switching environments or testing another version.
- Cleanup is best-effort: if another script changes the same properties, the final restored value may differ from the original value.

## Troubleshooting

**The UI does not appear**
- Check the console for dependency-loading errors.
- Verify that the UI library is reachable and compatible with the script's expected API.
- Confirm that the environment supports the required APIs.

**A hotkey does nothing**
- Make sure the UI is not capturing the key and that the hotkey toggle is enabled.
- Check for conflicts with the experience's own controls.
- Verify the current key assignments in the script and UI.

**Movement or camera behavior is inconsistent**
- Test in a simple, permitted test place.
- Check whether the experience or another local script overrides movement or camera properties.
- Remember that client-side changes may not be authoritative or replicated by the server.

**Settings do not restore exactly**
- Unload the script and inspect the current camera and character state.
- Another script, respawn, or camera replacement can interfere with restoration.
- Restart the test session if the environment remains in an unexpected state.

## Compatibility and limitations

- R6, R15, and custom character rigs may behave differently.
- Roblox experiences may replace or validate movement and camera behavior.
- Client-side changes do not guarantee server-side effects or replication.
- External libraries and client environments can change independently.
- The scripts have not been verified across every experience, client version, or avatar setup.
- Cleanup attempts to restore captured state but cannot guarantee restoration if the environment changes concurrently.

## Development

When reporting an issue, include:

- The script name and the feature involved.
- Steps to reproduce the behavior.
- Any relevant error message, with personal information removed.
- The environment and avatar rig used for testing.
- Whether the problem occurs in a clean test place.

Keep changes focused and document behavior changes in the README. Avoid committing credentials, tokens, private logs, or unrelated user data.

## License

**No license is currently specified.** Until a license is added, do not assume that redistribution or modification is permitted. See [Choose a License](https://choosealicense.com/) to select an appropriate license.

---

**Project name:** Scriptoid  
**Language:** Luau  
**Platform:** Roblox  
