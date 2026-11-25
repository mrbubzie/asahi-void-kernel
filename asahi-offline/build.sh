#!/bin/bash
set -euo pipefail

version=7.3.6+0
tag=asahi-7.3.4-2
void_commit=d3d55abb534a74b30abbff3d7b5bcfb98e60941d
source_sha=726c1ba2a9e0ba2481f2e73372d5d3849d41a3478f2580d92af66b3fe7722401
mirror=https://repo-default.voidlinux.org/current/aarch64
case "$VOID_LIBC" in
    glibc) arch=aarch64 ;;
    musl) arch=aarch64-musl ;;
    *) echo "Unsupported libc: $VOID_LIBC" >&2; exit 1 ;;
esac
test "$(xbps-uhelper arch)" = "$arch"
xbps-install -Syu xbps
xbps-install -Syu
xbps-install -Sy git curl ca-certificates util-linux shadow xz coreutils

# The runner rejects xbps-uunshare's user namespace ID mapping.
getent group xbuilder >/dev/null || groupadd --system xbuilder
uchroot=$(command -v xbps-uchroot)
chown root:xbuilder "$uchroot"
chmod 4750 "$uchroot"
useradd --create-home --groups xbuilder builder
work=/home/builder/void-packages
runuser -u builder -- git init "$work"
runuser -u builder -- git -C "$work" fetch --depth 1 https://github.com/void-linux/void-packages.git "$void_commit"
runuser -u builder -- git -C "$work" checkout --detach FETCH_HEAD
cd "$work"

template=srcpkgs/linux-asahi/template
grep -Fq 'archive/asahi-${version/+/-}.tar.gz' "$template"
grep -qx 'revision=1' "$template"
# Pin Rust externs to the kernel-built libraries in Kbuild's host directory.
sed -i '/^pre_configure() {$/,/^}$/s|/$(obj)/lib|/$(obj)/host/lib|g' "$template"
sed -i -e "s/^version=.*/version=$version/" \
    -e "s/^checksum=.*/checksum=$source_sha/" \
    -e "s|^distfiles=.*|distfiles=\"https://github.com/AsahiLinux/linux/archive/refs/tags/$tag.tar.gz\"|" \
    -e 's/ oldconfig$/ olddefconfig/' \
    -e '/# Always use our revision/i\	grep -qx "CONFIG_RUST=y" .config || msg_error "Asahi requires Rust support.\\n"\n\tgrep -Eq "^CONFIG_DRM_ASAHI=[ym]$" .config || msg_error "Asahi GPU driver was disabled.\\n"' "$template"
# Apply the reviewed stable updates through Void's normal patch hook.
(cd /kit/patches && sha256sum -c SHA256SUMS)
patchdir=srcpkgs/linux-asahi/patches
mkdir -p "$patchdir"
for update in asahi-stable-7.3.4-5 asahi-stable-7.3.5-6; do
    xz -dc "/kit/patches/$update.xz" > "$patchdir/$update.patch"
    printf '%s\n' '-Np1 --fuzz=0' > "$patchdir/$update.patch.args"
    printf '%s\n' "$update.patch" >> "$patchdir/series"
done
sed -i '/^do_configure() {$/a\	test "$(make -s kernelversion)" = "7.3.6" || msg_error "Unexpected source version.\\n"' "$template"
sed -i '/^do_install() {$/a\	test "$(cat include/config/kernel.release)" = "${_kernver}" || msg_error "Kernel release and XBPS module directory differ.\\n"' "$template"
printf '%s\n' 'XBPS_CHROOT_CMD=uchroot' >> etc/conf
chown -R builder:builder "$work"

runuser -u builder -- ./xbps-src binary-bootstrap
runuser -u builder -- ./xbps-src -j "$(nproc)" pkg linux-asahi
kernel="linux-asahi-${version}_1"
headers="linux-asahi-headers-${version}_1"

repo=/output/repository
mkdir -p "$repo"
cp "hostdir/binpkgs/$kernel.$arch.xbps" "hostdir/binpkgs/$headers.$arch.xbps" "$repo/"
xbps-rindex -a "$repo/"*.xbps

# Resolve the full dependency closure against an empty package database so
# dependencies installed in the build container are still downloaded.
roots=$(mktemp -d)
mkdir -p "$roots/download/var/db/xbps/keys" "$roots/check" "$roots/cache"
cp common/repo-keys/*.plist "$roots/download/var/db/xbps/keys/"
packages=("$kernel" "$headers" asahi-base asahi-scripts asahi-audio)
xbps-install -yDiM -r "$roots/download" -c "$roots/cache" \
    --repository "$repo" --repository "$mirror" "${packages[@]}"
for package in "$roots/cache/"*.xbps; do
    case "${package##*/}" in
        linux-asahi-[0-9]*|linux-asahi-headers-[0-9]*)
            if [[ "${package##*/}" != "$kernel.$arch.xbps" && "${package##*/}" != "$headers.$arch.xbps" ]]; then
                echo "Unexpected kernel package: $package" >&2
                exit 1
            fi
            ;;
        *) cp "$package" "$repo/" ;;
    esac
done
xbps-rindex -a "$repo/"*.xbps

# Verify the same transaction with only the artifact repository and no network.
unshare -n xbps-install -ni -r "$roots/check" --repository "$repo" "${packages[@]}"

printf '%s\n' "$arch" > /output/ARCH
printf 'Source tag %s\nSource SHA-256 %s\nVoid templates %s\n' \
    "$tag" "$source_sha" "$void_commit" > /output/BUILD.txt
printf '%s\n' 'Integrated stable updates: 7.3.4 -> 7.3.5 -> 7.3.6 (custom Asahi build)' >> /output/BUILD.txt
cat /kit/patches/SHA256SUMS >> /output/BUILD.txt
cp /kit/install-offline.sh /kit/OFFLINE-INSTALL.md /output/
cd /output
sha256sum ARCH BUILD.txt OFFLINE-INSTALL.md install-offline.sh repository/* > SHA256SUMS
