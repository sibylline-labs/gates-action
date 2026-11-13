#!/usr/bin/env bash
# Install the eris binary from a GitHub release and verify it against the
# release's SHA256SUMS before it is made executable.
#
# Inputs (environment):
#   ERIS_REPOSITORY  GitHub repository whose releases carry the eris binary
#   ERIS_TOKEN       token that can read that repository's releases
#   ERIS_VERSION     release tag; empty selects the latest release
#   RUNNER_OS, RUNNER_ARCH, RUNNER_TEMP, GITHUB_ENV   set by the runner
#
# Output: ERIS_BIN=<path to the installed binary>, appended to $GITHUB_ENV.
set -euo pipefail

: "${RUNNER_OS:?RUNNER_OS is not set}"
: "${RUNNER_ARCH:?RUNNER_ARCH is not set}"
: "${RUNNER_TEMP:?RUNNER_TEMP is not set}"
: "${GITHUB_ENV:?GITHUB_ENV is not set}"
: "${ERIS_REPOSITORY:?ERIS_REPOSITORY is not set}"
: "${ERIS_TOKEN:?ERIS_TOKEN is not set}"

case "$RUNNER_OS/$RUNNER_ARCH" in
  Linux/X64) target="linux-x64" ;;
  macOS/ARM64) target="darwin-arm64" ;;
  *)
    echo "::error::unsupported runner $RUNNER_OS/$RUNNER_ARCH; eris is published for Linux/X64 and macOS/ARM64"
    exit 1
    ;;
esac

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    shasum -a 256 "$1" | awk '{ print $1 }'
  fi
}

download_dir="$RUNNER_TEMP/eris-dl"
install_dir="$RUNNER_TEMP/eris"
asset="eris-$target"
mkdir -p "$download_dir" "$install_dir"

GH_TOKEN="$ERIS_TOKEN" gh release download ${ERIS_VERSION:+"$ERIS_VERSION"} \
  -R "$ERIS_REPOSITORY" -p "$asset" -p SHA256SUMS -D "$download_dir" --clobber

# SHA256SUMS lines are "<hash>  <name>"; a binary-mode line is "<hash> *<name>".
expected="$(awk -v name="$asset" '$2 == name || $2 == "*" name { print $1; exit }' "$download_dir/SHA256SUMS")"
if [ -z "$expected" ]; then
  echo "::error::SHA256SUMS has no entry for $asset"
  exit 1
fi

# Hash the file at its final path, so the bytes that are verified are the bytes
# that run. It is made executable only after the hashes match.
cp "$download_dir/$asset" "$install_dir/eris"
actual="$(sha256_of "$install_dir/eris")"
if [ "$actual" != "$expected" ]; then
  echo "::error::checksum mismatch for $asset: expected $expected, got $actual"
  rm -f "$install_dir/eris"
  exit 1
fi

chmod +x "$install_dir/eris"
printf 'ERIS_BIN=%s\n' "$install_dir/eris" >> "$GITHUB_ENV"
"$install_dir/eris" --version
