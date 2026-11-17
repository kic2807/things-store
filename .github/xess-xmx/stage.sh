#!/bin/sh
# One-shot: copies the package into /out (app data, seen by the desktop as
# a folder in steamheadless' home). A new release is unpacked over the old
# one, as upstream's update steps say, so the bundles install.sh downloaded
# (igc/, xess/, ffx/) and the compiled-kernel cache are kept. Runs as
# steamheadless (1000), so everything it writes already belongs to the user
# who runs the package; /out must be writable by that user.
set -e
new=$(cat /pkg/.release)
old=$(cat /out/.release 2>/dev/null || true)
if [ "$new" != "$old" ]; then
    cp -a /pkg/. /out/
    echo "xess-xmx: release $new staged (was ${old:-none})"
else
    echo "xess-xmx: release $new already staged"
fi
