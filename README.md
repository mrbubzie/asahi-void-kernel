# Build Void Asahi 7.3.6 packages for offline installation

1. Copy `.github/workflows/build-asahi-offline.yml` and the entire
   `asahi-offline/` directory to the root of your GitHub repository.
2. Open **Actions → Build Void Asahi 7.3.6 offline XBPS bundle → Run workflow**.
   Pick `glibc` for `aarch64` or `musl` for `aarch64-musl` as reported
   by `xbps-uhelper arch` on the destination Mac. If you have a larger Linux
   ARM64 runner, enter its label. The default is `ubuntu-24.04-arm`.
3. Download the artifact from the completed run and extract it on the Mac.
   Run `sh install-offline.sh` from the extracted directory.

The workflow builds the kernel and headers using Void's kernel template and
downloads the support packages with their runtime dependencies. It verifies
resolution against the finished repository with networking disabled before
upload. The workflow builds packages for an existing Void system.

The source is the checksum-pinned AsahiLinux tag `asahi-7.3.4-2` plus the
Linux stable 7.3.5 and 7.3.6 increments. The included patches are adapted
for Asahi. Duplicate Broadcom Wi-Fi and Rust changes are already present,
two device-tree whitespace changes already have the intended indentation,
and the ALSA PCM and SoC changes were merged with Asahi's audio code.
The expected kernel release is `7.3.6+0-asahi_1`. The +0 identifies this
local package build. Both patches were applied with zero fuzz to a clean
source archive and the patched tree reported 7.3.6.

The default is a standard ARM64 runner. The artifact stays available for
one day. Download it before it expires. Budget for up to five hours of
runner time per attempt. To save the ZIP contents into an existing local
checkout, extract this kit at the repository root and commit both the
workflow and the entire asahi-offline directory, including patches/.

Original upstream inputs:
- https://github.com/AsahiLinux/linux/releases/tag/asahi-7.3.4-2
- https://cdn.kernel.org/pub/linux/kernel/v7.x/incr/patch-7.3.4-5.xz
- https://cdn.kernel.org/pub/linux/kernel/v7.x/incr/patch-7.3.5-6.xz
