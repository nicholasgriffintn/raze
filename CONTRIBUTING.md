# Contributing to Raze

Incorrect HID commands can make support appear broader than it is and may cause
unexpected device behaviour. Keep catalogue and protocol changes conservative,
evidence-led, and read-only until the command family is known.

## Set up the project

Use macOS 13 or later with Xcode or a Swift 5.9-or-later toolchain.

```sh
swift test
swift run Raze
```

Run source builds only when hardware behaviour must be checked. macOS may require
Input Monitoring permission for the terminal or IDE launching Raze.

## Make a focused change

- Search for an existing model, encoder, or shared utility before adding one.
- Keep UI composition separate from protocol, persistence, and transport logic.
- Fix type errors directly; do not bypass them with casts.
- Add coverage for new validation, state transitions, protocol bytes, and error
  paths.
- Avoid new dependencies unless the change cannot be implemented safely with
  the existing toolchain.
- Use British English in user-facing text and documentation.

Run the relevant checks before opening a pull request:

```sh
swift test
swift package dump-package >/dev/null
plutil -lint Support/Info.plist
bash -n Scripts/package-app.sh
```

For packaging changes, also run:

```sh
VERSION=0.1.0 BUILD_NUMBER=1 bash Scripts/package-app.sh
codesign --verify --strict --verbose=2 dist/Raze.app
lipo -archs dist/Raze.app/Contents/MacOS/Raze
unzip -t dist/Raze.zip
```

## Report hardware evidence

Product names are not protocol evidence. Razer reuses names and command families
across hardware revisions, connection modes, and product IDs. Do not publish
serial numbers, location IDs, registry IDs, Apple account details, or signing
material.

Use this template in an issue or pull request:

```markdown
## Hardware evidence

- Device name and exact variant:
- Razer product number, if printed on the device:
- USB vendor ID: 0x1532
- USB product ID (PID):
- Connection mode: wired / receiver / Bluetooth
- macOS version:
- Mac architecture: Apple silicon / Intel
- Raze commit:
- Existing Raze support level: absent / detection only / community control
- Public protocol source or prior implementation:

## Observed behaviour

- Device appears in Raze: yes / no
- Product name shown:
- Feature-report interface size:
- Transaction ID tested:
- Protocol family tested: standardMatrix / extendedMatrix / mouseExtendedMatrix
- Lighting targets tested:
- Effects tested and visible result:
- Brightness tested and visible result:
- Response status or error:
- Behaviour after reconnecting and after changing connection mode:

## Safety and privacy

- [ ] I removed serial, location, registry, account, and signing identifiers.
- [ ] I did not derive this contribution from leaked or confidential material.
- [ ] I can repeat the result on the hardware described above.
```

Use **System Information → USB** to obtain the vendor and product IDs without
sharing a full system report. Describe both successful and failed commands, but
do not post indiscriminate HID dumps that contain unique identifiers.

## Change the device catalogue safely

`Sources/RazerCore/DeviceCatalog.swift` is an allow-list for writes, not a list
of product-name guesses.

- Add a unique PID with the exact observed connection mode and model name.
- Use `.detected(...)` when only identity is known. Detection-only definitions
  have no protocol, targets, effects, brightness, or writable transaction ID.
- Use `.supported(...)` only when public protocol evidence identifies the
  transaction ID, command family, targets, effects, and brightness behaviour.
- Treat wired, receiver, and Bluetooth PIDs separately. Evidence for one mode
  does not establish another.
- Do not infer protocol support from a nearby PID, similar model name, release
  year, or another operating system detecting the device.
- Do not copy mappings from confidential firmware, leaked SDKs, or sources whose
  licence does not permit the contribution.
- Keep unknown or uncertain capabilities read-only. A useful detection-only
  entry is safer than an unverified write mapping.

The current `.supported(...)` helper advertises every effect and brightness.
If hardware evidence supports only a narrower capability set, extend the data
model and tests to represent that limitation instead of overstating support.

Add or update tests to prove:

- the catalogue count and PID uniqueness;
- the expected product name, kind, support level, transaction ID, protocol, and
  targets;
- detection-only entries have no writable capabilities; and
- exact command bytes and response validation for any new protocol behaviour.

## Change protocol code safely

Keep report construction in `RazerCore`, not in views or `HIDTransport`.

- Preserve the 90-byte report boundary and the 80-byte argument limit.
- Validate checksum, transaction ID, command class, command ID, response status,
  response length, and declared argument length.
- Add byte-level tests for each command family and edge case.
- Keep busy-response retries bounded.
- Never add a generic raw-command UI or a fallback that writes to unknown
  devices.
- Explain the public source and hardware observation behind new constants in the
  pull request.

Test protocol changes against the least valuable suitable device first. Stop if
the device disconnects, resets unexpectedly, becomes unresponsive, or returns a
rejected status.

## Open a pull request

Keep the description concise:

- Explain the concrete problem.
- Summarise the functional changes.
- Include the hardware evidence template when device behaviour changes.
- State the tests and packaging checks run.
- Call out untested hardware, connection modes, and other residual risks.

Do not include generated `.build`, `dist`, Xcode user-state, or profile files.
By submitting a contribution, you agree that it is provided under
[Apache-2.0](LICENSE), as described in section 5 of that licence.
