# 開発者向けメモ

ユーザー向けの説明・動作環境・セットアップは [README](README.md) を参照

---

## Overview

BTAudioSwitch works as a one-way flow: detect → plan → write.

1. **Detect**: Every time the CoreAudio device list changes, re-read whether the registered device's output and input endpoints are present, and compute the difference from the previous reading.
2. **Plan**: From that difference, the settings (priority lists and so on), and the current device list, decide in a pure function, per direction (output and input), which UID should become the default.
3. **Write**: Following the plan, write CoreAudio's default output and default input.

Layer dependencies point one way: the switching logic (Switching) reaches CoreAudio and IOBluetooth only through the protocols of the Audio and Bluetooth layers, alongside their plain value types and pure helpers. Nothing points back, so swapping the boundary implementations (CoreAudio, IOBluetooth) leaves the switching logic unchanged.

---

## Glossary

- **Registered device** — The Bluetooth audio device the user picked as the target of switching. Only one can be held.
- **Endpoint** — An output or input port that the registered device exposes in CoreAudio. The same device can appear as separate output and input devices, so each direction is tracked separately.
- **Appearance / disappearance** — Compared with the previous detection, an endpoint that "was absent and is now present" or "was present and is now gone". When the UID is replaced, it is treated as the appearance of the new UID.
- **Fallback target** — When the disconnect mode is the priority list, the device written as the default in place of an endpoint that disappeared. It is the first candidate, from the top of the priority list, that is available at that moment.
- **Priority list** — The candidates for the fallback target, in order. Output and input each have their own list, edited with the same UI component.
- **Following app** — A generic name for an app, such as an EQ app, that makes itself follow the system default output. It does not refer to any particular implementation.

---

## Rules to Keep

### Detection and Writing

- Connection and disconnection are captured only from differences in the CoreAudio device list; Bluetooth connect and disconnect notifications are not used. A Bluetooth notification arrives when a connection is merely attempted and does not guarantee success, and its order relative to CoreAudio is not defined, so using it would require waiting for the two to line up. With list differences, the write target being present in the list is itself the condition. The Bluetooth side is used only for the paired-device list, the connect and disconnect operations, and reading the battery level.
- The default input and output are written only when the appearance or disappearance of a registered device's endpoint is detected, at most once per direction for each detection. Changes to the default input and output themselves are not observed. A reactive design would end up in a write war with a following app, or keep overwriting the input and output the user picked by hand.
- Because the defaults are not observed, it is impossible to tell whether the OS or the user replaced the default at the moment of disappearance. So the current default is not read before writing, and the result is not checked and retried after writing. A retry is the same as rewriting in reaction to a change of the default, which would bring the reactive design back in.
- Nothing is written at app launch or when a settings change replaces or clears the registered device (including resyncing its name). The device list and the endpoints are re-read, and the result is not treated as a difference. Settings changes unrelated to the registered device do not even trigger a re-read.
- The connect and disconnect operations only attempt to connect or disconnect the device; they do not write the default input or output. Writing is funneled into the path that detects the appearance or disappearance of endpoints, keeping a single write path.
- The input-switching setting is evaluated at each appearance or disappearance; while it is off, the default input is never touched in either case.
- Do not depend on the existence or internals of other apps (a driver's UID, name, or transport-type quirks). There is no branching on whether a following app is present.

### Device Identification

- Devices are identified by UID (CoreAudio) and Bluetooth address. Names are only a cache for display. The registered device's name is resynced to the OS's current name whenever the menu opens or the settings window becomes key (renaming the device on the OS side does not unregister it; only the display follows).
- There is no public way to link a Bluetooth address to a CoreAudio UID; matching relies on the observation that the UID of a Bluetooth endpoint contains the address. This matching is confined to one place (BluetoothEndpointMatch) so that, if the assumption breaks, the impact stays there.
- Address normalization is also confined to one place (BluetoothAddress). The registered device's address is stored in normalized form when it is taken from the paired-device list, and it is never normalized again afterwards. Normalization is applied only to notations that come from outside (the paired-device list, UIDs, and the system_profiler output).

### Candidates

- AirPlay is not put into the output priority list. An AirPlay device disappears from the CoreAudio device list the moment it is selected, so it cannot be held as a fallback target.
- Virtual and aggregate devices other than AirPlay are deliberately kept as candidates. Telling whether a device belongs to a following app would depend on another app's internals, so whether to pick it is left to the user. The candidates added to a priority list and the fallback targets are decided by the same criteria (CandidatePolicy).
- The registered device's own endpoints are not offered as candidates to add to a priority list, because they do not exist at disconnection.
- The candidates for the target device are limited to audio devices among the paired Bluetooth devices (judged in IOBluetoothDirectory). A device that is already registered stays in the candidates even if it does not meet the criteria, so that the selection does not vanish from the display.

### Battery Level

- The battery level is read first from a private IOBluetooth property (the same value as the macOS menu), and if that fails, from the output of system_profiler. Public means alone sometimes cannot get the value even when macOS has it. The private means may be lost in an OS update, but losing it only moves reading to the next source or leaves the level undisplayed; it does not affect switching.
- The private IOBluetooth property is read in a short-lived child process that runs the app's own executable, not in the running app. Within a long-running process the value delivered at connection time can be empty, and later updates to it do not reach the process, so reading it in the app can keep returning nothing.
- The battery level is kept independent of the switching logic, in a separate component (BatteryMonitor), so that success, failure, or delay in reading does not spill over into switching.
- The battery level is read only while the registered device is connected, at these moments: when the app sees it become connected (including at launch and when the registration switches to a connected device), and when the user looks at it (opening the menu, the settings window becoming key). It is not polled. Reading it at connection time lets it show immediately the next time the user looks.

### Threads

- State is gathered on main. External calls that can block (connect, disconnect, running an external command) run off main while main awaits their result. Calls that return without waiting (reading values from IOBluetooth, writing the CoreAudio defaults) are made on main.
- The listener for device-list changes is registered on a dedicated queue separate from the thread doing the work, and it only enqueues onto main there. The HAL delivers synchronously when a device disappears, so waiting on the same queue would deadlock.
- Exception: while the Bluetooth permission prompt is waiting for an answer, IOBluetooth calls on main block. This happens only until the prompt is answered (which, with ad-hoc signing, is again after each rebuild).

### How Failures Are Shown

- The app shows no alerts. Connect and disconnect are operations that only attempt, and the result is conveyed by the menu and the settings window showing the actual state.
- While a connect or disconnect operation is in progress, the in-progress state lasts until the result appears in the device list (or until the time limit), even if the operation succeeded. There is a lag between the operation completing and the list reflecting it, and no connect or disconnect operation is accepted during that lag.
- For operations whose result is visible on the spot, the result is conveyed by returning the display to the actual state. The launch-at-login toggle returns to the system's state if registration fails.
- Failures in processing not tied to a user operation (writing the default input and output, saving and loading settings) are not reported to the user; at most they are logged. A battery level that cannot be read is simply left undisplayed.

### Saving Settings

- Saved settings are read by filling in only the missing items with their defaults. Adding an item does not lose the saved settings. Renaming a top-level item resets that item to its default. Renaming a key inside a nested item, or changing the notation of a value (a choice's value), makes the settings unreadable and resets all of them to their defaults.

### Launch and Windows

- The launch path (whether as a login item) is not distinguished. The settings window opens at launch only when no device is registered, and it always opens when the .app is opened again. While the settings window is open, and for a fixed time right after launch, the icon is shown regardless of the icon display mode. Together these make the menu reachable even when the icon is hidden, both by "the icon appears for a while right after launch" and by "open again → the settings window and the icon appear → quit from the menu", so do not change only one of them.
- The settings window has a fixed width, and its content size does not resize the window, to keep the decided appearance. The height is capped at the screen's visible area when the window is created, and whatever does not fit is reached by scrolling the Form.
- The priority list does not use the system table component; it is built by stacking rows vertically. The table component cannot size its height to its content, and unless the row height is hard-coded, the last row gets cut off or extra space appears.

---

## How the Flow Differs With and Without a Following App

**On connection**: When the registered device's output appears, the app writes that device as the default output. Without a following app, sound comes straight from the registered device. With a following app, the following app picks up that write, and sound comes from the registered device through the following app.

**On disconnection**: When the disconnect output target is automatic, nothing is written and the macOS choice is left as is. When it is the priority list, once the registered device's output disappears, the app writes the first available device from the output priority list as the default output.

- Without a following app, macOS itself replaces the vanished device with another device, and the app's write overrides that with the top of the priority list.
- With a following app, the default output stays on the following app's device, so the app's write serves to decide where the following app forwards to.
- When the priority list is empty or none of its devices are available, nothing is written in either configuration.

When input switching is on, the input works with the same structure.

---

## Build and Test

`make test` runs `swift test` and, when it passes, cleans up the throwaway storage the tests create. The decision logic (pure functions) and the switching logic wired with fake Audio and Bluetooth are automated here. The CoreAudio read path is verified by going through the real HAL, read-only.

Tests never call IOBluetooth. Calling it from the test runner gets it force-terminated, because the runner does not hold the TCC permission. Fetching paired devices, connecting and disconnecting, and reading the battery level are replaced with fakes.

Writing the default input and output, operations through IOBluetooth, reading the battery level, and registering the login item all require real hardware, so they are outside the automation and are checked on real hardware whenever they change.

---

## Known Constraints

Because signing is ad-hoc for self-built apps, registering the login item may additionally require approval on the system side.
