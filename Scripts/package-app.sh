#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

version="${VERSION:-0.1.0}"
build_number="${BUILD_NUMBER:-1}"
app="$repo_root/dist/Raze.app"
archive="$repo_root/dist/Raze.zip"
binary="$repo_root/.build/apple/Products/Release/Raze"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "VERSION must be a semantic version such as 1.2.3." >&2
    exit 1
fi
if [[ ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
    echo "BUILD_NUMBER must be a positive integer." >&2
    exit 1
fi

swift build -c release --arch arm64 --arch x86_64

rm -rf "$app"
rm -f "$archive" "$archive.sha256"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/Raze"
cp "$repo_root/Support/Info.plist" "$app/Contents/Info.plist"
cp "$repo_root/Support/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
cp "$repo_root/LICENSE" "$app/Contents/Resources/LICENSE"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$app/Contents/Info.plist"

codesign --force --sign - "$app"

codesign --verify --strict --verbose=2 "$app"
architectures="$(lipo -archs "$app/Contents/MacOS/Raze")"
if [[ "$architectures" != *"arm64"* || "$architectures" != *"x86_64"* ]]; then
    echo "Packaged binary is not universal: $architectures" >&2
    exit 1
fi

ditto -c -k --keepParent --norsrc --noextattr "$app" "$archive"
(cd "$repo_root/dist" && shasum -a 256 Raze.zip > Raze.zip.sha256)
unzip -t "$archive" >/dev/null
(cd "$repo_root/dist" && shasum -a 256 -c Raze.zip.sha256)

echo "Created dist/Raze.app, dist/Raze.zip, and dist/Raze.zip.sha256"
