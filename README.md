# seroid

A configurable Roblox movement and camera utility built with [VibeUI](https://pages.sirmemegithub.com/VibeUI/).

`seroid` provides a single interface for adjusting movement speed, jump settings, and camera field of view, alongside movement options and configuration controls.

> **Status:** Experimental. Compatibility and individual features have not been verified across every executor, avatar rig, or Roblox experience.

## Companion script: Curvoid

`curvoid.lua` is a separate, standalone black-and-cyan camera utility. It does not replace or modify `seroid.lua` and does not require VibeUI or an external HTTP-loaded UI library.

- **Backward snap** — Q or F briefly rotates the camera 180 degrees, then restores it.
- **Upward snap** — R briefly tilts the camera upward; the default angle is 45 degrees.
- **Controls UI** — Rebind the main hotkeys, enable or disable hotkeys, and adjust snap duration and upward angle.
- **About page** — Displays Curvoid, version v1.0.0, and creator vel1ous.
- **Cleanup** — The window's close button disconnects the script's event connections and removes its UI.

To use Curvoid, run `curvoid.lua` separately as a LocalScript in `StarterPlayerScripts` or in a compatible client-side Luau test environment. Check the rules of the experience before using client-side camera modifications.

## Features

- **Speed control** — Adjustable speed with presets.
- **Movement options** — Smooth acceleration, smoothing strength, grounded-only mode, and vertical velocity handling.
- **Jump control** — Toggleable jump boost with power and height modes.
- **Camera settings** — Adjustable field of view, presets, and reset controls.
- **Configuration** — Quick profile save/load controls and a reset-to-defaults option.
- **Interface** — VibeUI-based menu, theme settings, and notifications.
- **Cleanup** — Disconnects tracked event connections and attempts to restore captured camera and jump settings.

## Requirements

- A compatible Luau environment with the APIs required by the script.
- Access to the VibeUI library.
- A Roblox character with a `Humanoid` and a suitable root part for movement features.

The script depends on external library hosting, so loading may fail if the source is unavailable or the environment blocks HTTP requests.

## Installation

1. Review the script you intend to run: `seroid.lua` or `curvoid.lua`.
2. For `seroid.lua`, install/access the VibeUI dependency and confirm that the environment supports its APIs.
3. For `curvoid.lua`, no external UI dependency is required; run it separately as a LocalScript in `StarterPlayerScripts` or in a compatible client-side Luau test environment.
4. Confirm that client-side modifications are permitted in your test environment.
5. Run only the script you want to test, then verify its controls in a controlled experience.

This project is intended for learning, experimentation, and authorized testing. Do not use it to disrupt other players or bypass rules in experiences where modifications are prohibited.

## Default controls

| Control | Default |
|---|---|
| Menu toggle | Right Ctrl |
| Speed toggle | Left Ctrl |
| Default speed | 37 |
| Default jump boost | Off |
| Custom FOV | Off |

Hotkey behavior can depend on the UI library version and the execution environment.

## Configuration

The interface includes controls for speed, movement smoothing, jump mode and value, camera FOV, and quick profiles.

Some configuration features depend on the installed VibeUI version. Test saving and loading profiles before relying on them.

## Compatibility and limitations

- R6, R15, and custom rigs may behave differently.
- Some experiences override movement locally or validate movement on the server.
- Executor APIs differ; compatibility with a specific executor is not guaranteed.
- The UI library is hosted externally and may change independently of this project.
- The script attempts to restore captured settings when unloaded, but restoration cannot be guaranteed if another script modifies the same properties.

## Dependencies

- [VibeUI repository](https://sirmemegithub.com/RealSlimShady2000/VibeUI)
- [VibeUI documentation](https://pages.sirmemegithub.com/VibeUI/)

Review third-party dependencies and their licenses before redistributing them.

## Contributing

Bug reports and constructive suggestions are welcome. When reporting an issue, include:

- The feature that failed.
- The error message, if any.
- The relevant environment and avatar rig.
- Steps to reproduce the problem.

Do not include account credentials, authentication tokens, or other private information in issues.

## Disclaimer

This is an independent community project and is not affiliated with or endorsed by Roblox or the VibeUI maintainers. Use it responsibly and follow the applicable platform rules.

## License

No license has been selected yet. Unless a license is added, others should not assume they have permission to redistribute or modify this project's code. See [Choose a License](https://choosealicense.com/) before selecting one.
