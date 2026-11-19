#!/bin/sh
# One-shot, before the desktop: copies the package into /out (app data:
# ~/.xess-xmx of steamheadless in the desktop). A new release is unpacked
# over the old one, as upstream's update steps say, so the bundles fetched
# below (igc/, xess/, ffx/) and the compiled-kernel cache are kept. Runs as
# steamheadless (1000), so everything it writes already belongs to the user
# who runs the package; /out must be writable by that user (setup sees to it).
#
# Also stages activate.sh (.things/), which Steam's unit runs before Steam,
# and fetches what install.sh would otherwise download at Steam's start.
# A failed download is only reported: install.sh tries again later.
set -e
new=$(cat /pkg/.release)
old=$(cat /out/.release 2>/dev/null || true)
if [ "$new" != "$old" ]; then
    cp -a /pkg/. /out/
    echo "xess-xmx: release $new staged (was ${old:-none})"
else
    echo "xess-xmx: release $new already staged"
fi
mkdir -p /out/.things
cp /things/activate.sh /out/.things/activate.sh

export HOME=/tmp
if ! ls /out/igc/neo/bin/ocloc* >/dev/null 2>&1; then
    echo "xess-xmx: fetching the compiler bundle (~95 MB)"
    bash /out/tools/get-igc.sh /out || echo "xess-xmx: compiler download failed"
fi
if [ ! -f /out/xess/libxess.dll ]; then
    echo "xess-xmx: fetching Intel's XeSS SDK libraries (~77 MB)"
    bash /out/tools/get-xess.sh /out || echo "xess-xmx: XeSS SDK download failed"
fi
if [ ! -f /out/ffx/amd_fidelityfx_loader_dx12.dll ] || [ ! -f /out/ffx/amd_fidelityfx_framegeneration_dx12.dll ]; then
    echo "xess-xmx: fetching AMD's FidelityFX files (~87 MB)"
    bash /out/tools/get-ffx.sh /out || echo "xess-xmx: FidelityFX download failed"
fi
echo "xess-xmx: ready"
