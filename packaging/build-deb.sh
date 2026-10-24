#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script_version=$(sed -n 's/^VERSION="\([0-9][^"]*\)"/\1/p' "$repo_root/pc-command-center.sh")
version=${1:-$script_version}
output_dir=${2:-$repo_root/dist}

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+~-][A-Za-z0-9.+~-]+)?$ ]]; then
    printf 'Error: invalid Debian package version: %s\n' "$version" >&2
    exit 2
fi
if [[ "$version" != "$script_version" ]]; then
    printf 'Error: requested version %s does not match script version %s\n' "$version" "$script_version" >&2
    exit 2
fi
if [[ ! -f "$repo_root/pc-command-center.1" ]]; then
    printf 'Error: generated man page pc-command-center.1 is missing; run make man\n' >&2
    exit 2
fi

mkdir -p -- "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd)
package_root=$(mktemp -d)
trap 'rm -rf -- "$package_root"' EXIT

install -D -m 755 "$repo_root/pc-command-center.sh" "$package_root/usr/bin/pcc"
install -D -m 644 "$repo_root/pc-command-center.1" "$package_root/usr/share/man/man1/pcc.1"
install -D -m 644 "$repo_root/readme.md" "$package_root/usr/share/doc/pc-command-center/README.md"
install -D -m 644 "$repo_root/CHANGELOG.md" "$package_root/usr/share/doc/pc-command-center/changelog.md"
mkdir -p "$package_root/DEBIAN"
cat > "$package_root/DEBIAN/control" <<CONTROL
Package: pc-command-center
Version: $version
Section: utils
Priority: optional
Architecture: all
Depends: bash, coreutils, grep, hostname, iproute2, procps, sed, mawk | gawk, ncurses-bin
Recommends: lm-sensors
Maintainer: PC Command Center contributors <san-rat@users.noreply.github.com>
Description: lightweight Linux terminal system dashboard
 PC Command Center is a Bash terminal dashboard for CPU, memory, disk,
 network, process, temperature, and optional battery telemetry.
CONTROL

artifact="$output_dir/pc-command-center_${version}_all.deb"
dpkg-deb --build --root-owner-group "$package_root" "$artifact"
printf 'Built %s\n' "$artifact"
