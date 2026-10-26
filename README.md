# Scriptoid

**A collection of configurable Roblox client-side movement and camera utilities, written in Luau.**

Scriptoid contains two independent scripts with different purposes. This README explains what each file does, its default controls, setup considerations, limitations, and how to report problems.

> [!IMPORTANT]
> Use these scripts only in Roblox experiences you own or in environments where the relevant modifications are explicitly permitted. Client-side changes are not authoritative server changes and may not replicate. Scriptoid is an independent project and is not affiliated with, endorsed by, or supported by Roblox.

## Contents

- [Project overview](#project-overview)
- [Scripts and features](#scripts-and-features)
- [Default controls](#default-controls)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Configuration and cleanup](#configuration-and-cleanup)
- [Troubleshooting](#troubleshooting)
- [Compatibility and limitations](#compatibility-and-limitations)
- [Security and dependencies](#security-and-dependencies)
- [Contributing and bug reports](#contributing-and-bug-reports)
- [License](#license)

## Project overview

| File | Purpose | UI / dependency notes |
| --- | --- | --- |
| `seroid.lua` | Movement tuning, jump settings, dash options, and camera field-of-view controls | Loads the external [VibeUI library](https://pages.sirmemegithub.com/VibeUI/). |
| `curvoid.lua` | Configurable camera actions, including a fast backward turn and smooth return | Includes a larger UI implementation; inspect the current source for its exact runtime requirements. |

The scripts are **separate tools**, not one combined script. Choose the file that matches the feature you want to test and review that file before running it.

## Scripts and features

### `seroid.lua` — movement and camera controls

- **Movement tuning:** adjustable movement speed, presets, and smoothing.
- **Grounded movement option:** setting to limit movement behavior to grounded states.
- **Jump settings:** toggleable jump boost with Power or Height mode.
- **Dash controls:** straight dash and backstab/flank options with configurable timing and distance-related settings.
- **Camera FOV:** optional custom field of view and presets.
- **Profiles and reset:** quick configuration controls.
- **Cleanup:** attempts to disconnect tracked connections and restore selected captured properties when unloaded.

### `curvoid.lua` — camera actions

- **Backward turn:** configurable fast turn with an eased return animation.
- **Upward camera action:** adjustable angle.
- **Motion tuning:** configurable turn, hold, and return durations.
- **Hotkeys:** enable or disable hotkeys and rebind supported actions.
- **Quick actions:** reset settings and cancel active camera motion.
- **Profiles:** profile saving/loading and autosave behavior, subject to the current runtime's file APIs.
- **Cleanup:** attempts to cancel active motion and restore captured camera state.

Feature details and defaults can change as the scripts evolve. The source code is the final reference for current behavior.

## Default controls

These are the documented defaults. UI settings, saved profiles, library behavior, or later source changes may alter them.

### `seroid.lua`

| Action / setting | Default |
| --- | --- |
| Open or close UI | Right Ctrl |
| Speed toggle | Left Ctrl |
| Dash system toggle | H |
| Straight dash | Q |
| Backstab / flank action | R |
| Movement speed | 37 studs/s |
| Jump boost | Off |
| Custom FOV | Off |
| Dash cooldown | 3.9 seconds |

Some controls are managed through UI keybinds. If a key does not respond, check both the script defaults and the active UI configuration.

### `curvoid.lua`

| Action / setting | Default |
| --- | --- |
| Backward camera turn | F |
| Upward camera action | R |
| Open or close UI | Right Ctrl |
| Backward turn angle | 180° |
| Turn duration | 0.09 seconds |
| Hold duration | 0.05 seconds |
| Return duration | 0.09 seconds |
| F cooldown | 2 seconds |

The default turn, hold, and return durations add up to approximately **0.23 seconds**. Actual motion can vary with frame rate, camera behavior, and other scripts.

## Requirements

Requirements vary by script and execution environment.

- A compatible Luau environment that supports the Roblox APIs used by the selected script.
- A local character with a `Humanoid` and suitable root part for movement-related features in `seroid.lua`.
- The required UI library and its expected API for the selected script.
- For profile saving/loading, an environment that supports the file APIs used by the script.
- Permission to test the intended behavior in the experience.

The scripts are not guaranteed to work in every Roblox experience, avatar rig, client environment, or UI-library version.

## Getting started

1. **Choose a script.** Read `seroid.lua` for movement-related controls or `curvoid.lua` for camera actions.
2. **Review the source.** Understand the code and its dependencies before running it.
3. **Check permissions.** Use a place you own or an environment where the intended modifications are allowed.
4. **Test in isolation.** Start in a simple test place and change one setting at a time.
5. **Check restoration.** Test unloading, respawning, and switching settings to see whether the expected movement and camera state is restored.

Do not run unfamiliar code just because it is hosted on GitHub. Review third-party libraries and remote code before trusting them.

## Configuration and cleanup

- Use each script's UI for the settings it exposes.
- Start with modest values and change one setting at a time.
- Use reset controls if a setting causes unexpected behavior.
- Avoid running both scripts simultaneously until you have tested possible keybind, camera, and UI conflicts.
- Unload the script before switching versions or test environments.
- Treat cleanup as **best-effort**, not a guarantee: respawns, camera replacement, other scripts, or interrupted actions may affect restoration.

Profile and autosave features depend on the current source and the file APIs available in the environment. Do not assume saved profiles are portable across versions.

## Troubleshooting

### The UI does not appear

- Check the runtime console for errors.
- Confirm that required dependencies are reachable and compatible.
- Verify that the environment supports the APIs the script uses.
- Review recent source changes if the script worked previously.

### A hotkey does nothing

- Confirm the feature and hotkey are enabled.
- Check whether the UI or another control is capturing the key.
- Look for conflicts with the experience or the other script.
- Recheck the current keybinds and saved profile.

### Movement or camera behavior is inconsistent

- Reproduce the issue in a clean, permitted test place.
- Check whether the character respawned or the camera was replaced.
- Check whether the experience or another local script changes the same properties.
- Remember that client-side behavior does not guarantee server-side effects.

### A profile will not save or load

- Check whether the environment supports the file APIs used by the script.
- Verify the profile name and file path.
- Look for read/write errors in the console.
- Keep a backup of configurations before changing script versions.

### Settings do not restore as expected

- Disable or unload the script and inspect the current character and camera state.
- Check for overlapping actions or another script modifying the same properties.
- If the session remains in an unexpected state, restart the test session.

## Compatibility and limitations

- R6, R15, and custom rigs may behave differently.
- Experience-specific movement rules and camera controllers can override or conflict with local changes.
- Client-side modifications may not replicate to the server.
- External libraries, APIs, and runtime environments can change independently.
- The scripts have not been verified across all experiences, client versions, or avatar configurations.
- Cleanup and state restoration are best-effort and can be affected by concurrent changes.
- No automated test suite or broad compatibility matrix is currently documented in this repository.

## Security and dependencies

`seroid.lua` loads an external UI library. Code fetched from a remote source can change after you review it, so inspect the dependency and its license and pin or vendor a reviewed version where appropriate. Review any remote-loading behavior in either script before running it.

Never place passwords, authentication tokens, private account data, or sensitive logs in source files or bug reports. Be cautious with third-party downloads and avoid running code you do not understand.

## Contributing and bug reports

When opening an issue, include:

- The affected file and feature.
- Clear steps to reproduce the issue.
- The expected behavior and what happened instead.
- Relevant error output with personal or sensitive information removed.
- The test environment and avatar rig, if relevant.
- Whether the issue also occurs in a clean test place.

Keep changes focused, update this README when user-visible behavior changes, and avoid committing secrets or unrelated personal data.

## License

**No project license is currently specified.** Until a license is added, do not assume that others have permission to redistribute or modify this repository. Third-party dependencies may have separate license terms.

If you maintain this project, choose and add a license that matches your intentions. See [Choose a License](https://choosealicense.com/) for an overview.

---

**Language:** Luau  
**Platform:** Roblox  
**Repository:** [nosuhup/Scriptoid](https://github.com/nosuhup/Scriptoid)
