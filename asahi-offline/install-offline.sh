#!/bin/sh
set -eu

cd "$(dirname "$0")"
sha256sum -c SHA256SUMS
read -r expected_arch < ARCH
actual_arch=$(xbps-uhelper arch)
if [ "$actual_arch" != "$expected_arch" ]; then
    echo "This bundle is for $expected_arch. This installation is $actual_arch." >&2
    exit 1
fi

run_xbps() {
    if [ "$(id -u)" -eq 0 ]; then xbps-install "$@"; else sudo xbps-install "$@"; fi
}

set -- linux-asahi-7.3.6+0_1 linux-asahi-headers-7.3.6+0_1 \
    asahi-base asahi-scripts asahi-audio
run_xbps -ni --repository "$PWD/repository" "$@"
run_xbps -i --repository "$PWD/repository" "$@"
