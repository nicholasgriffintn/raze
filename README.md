# Raze

Raze is a native macOS app for controlling lighting on Razer devices. It uses
IOKit directly, with no daemon, account, analytics, or network access.

Raze recognises a maintained list of product IDs. Community control is enabled only where a protocol mapping exists; unknown and unmapped devices remain read-only.

## Install

Raze requires macOS 13 or later.

- Download `Raze.zip` and `Raze.zip.sha256` from the
  [latest GitHub Release](../../releases/latest).
- Run `shasum -a 256 Raze.zip` and compare the result with the checksum file.
- Unzip the app, move it to `/Applications`, and open it.
- Grant Input Monitoring access if macOS requests it.

**Raze is currently only released to GitHub.** macOS may show a Gatekeeper warning when you first open the app, which you will need to accept.

## Features

- Automatic discovery and refresh
- Static, spectrum, breathing, reactive, wave, and off effects where supported
- Interactive device map with direct per-zone lighting and brightness controls
- Local profiles available from the window and menu bar
- Universal Apple silicon and Intel builds

Profiles are stored at:

```text
~/Library/Application Support/Raze/profiles-v1.json
```

Raze does not currently manage DPI, key bindings, macros, or firmware.

## Device support

The catalogue contains a list of known Razer product IDs:

- **Community control:** a protocol, transaction ID, targets, and effects are
  mapped.
- **Detection only:** the device is identified but Raze sends no commands.

These mappings are community-derived and not every device has been tested on
physical hardware. Wired, receiver, and Bluetooth modes can expose different
product IDs.

To add or correct support, follow the hardware-evidence process in
[CONTRIBUTING.md](CONTRIBUTING.md). Raze deliberately avoids guessed commands.

### Device not appearing

- Reconnect the device and press **Command-R**.
- Enable Raze under **System Settings → Privacy & Security → Input Monitoring**.
- Quit and reopen Raze after changing permission.
- Quit other device-control software that may have opened the same HID
  interface.
- Include the displayed or System Information USB product ID in a support
  report.

Raze can still list devices while Input Monitoring is denied, but macOS may
block lighting changes until permission is granted.

## Develop

Building requires Xcode or Swift 5.9 or later.

```sh
swift test
swift run Raze
```

Create a universal package:

```sh
VERSION=0.1.0 BUILD_NUMBER=1 bash Scripts/package-app.sh
```

The output is written to `dist/` as `Raze.app`, `Raze.zip`, and
`Raze.zip.sha256`.

If you'd like to run tests with connected Razer hardware, set the `RAZE_HARDWARE_TEST` environment variable:

```sh
RAZE_HARDWARE_TEST=1 swift test --filter HIDTransportTests
```

## GitHub releases

`.github/workflows/ci.yml` tests and packages every pull request and push to
`main`. `.github/workflows/release.yml` publishes an ad-hoc signed GitHub
Release when a `vMAJOR.MINOR.PATCH` tag is pushed. No external signing account
or credentials are required.

Publish a release:

```sh
git tag v0.2.0
git push origin v0.2.0
```

The workflow tests, packages, verifies, attests, and uploads the zip and checksum
to GitHub Releases. See [CONTRIBUTING.md](CONTRIBUTING.md) for local verification
and [SECURITY.md](SECURITY.md) for private vulnerability reports.

## Licence

Raze is available under the [Apache License 2.0](LICENSE). It is an independent
community project and is not affiliated with or endorsed by Razer Inc.
