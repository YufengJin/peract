#!/usr/bin/env bash
# Install CoppeliaSim V4.1.0 Player (Ubuntu 20.04) into peract/third_party/CoppeliaSim.
# Idempotent: safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERACT_ROOT="$(dirname "$SCRIPT_DIR")"
COPPELIA_DIR="$PERACT_ROOT/third_party/CoppeliaSim"
TARBALL_URL="https://downloads.coppeliarobotics.com/V4_1_0/CoppeliaSim_Player_V4_1_0_Ubuntu20_04.tar.xz"
TARBALL_TMP="/tmp/coppeliasim_v4_1_0.tar.xz"

# 1. Idempotent check
if [ -f "$COPPELIA_DIR/coppeliaSim.sh" ]; then
    echo "✓ CoppeliaSim already installed at $COPPELIA_DIR"
    exit 0
fi

# 2. Download (63 MB)
mkdir -p "$PERACT_ROOT/third_party"
echo ">> Downloading CoppeliaSim V4.1.0 Player (Ubuntu 20.04)..."
wget -q --show-progress "$TARBALL_URL" -O "$TARBALL_TMP"

# 3. Extract
echo ">> Extracting to $COPPELIA_DIR..."
mkdir -p "$COPPELIA_DIR"
tar xf "$TARBALL_TMP" -C "$COPPELIA_DIR" --strip-components=1
rm "$TARBALL_TMP"

# 4. PyRep pre-requisite: usrset.txt (else PyRep setup.py fails reading version)
echo "allowOldEduRelease=7501" > "$COPPELIA_DIR/system/usrset.txt"

# 5. PyRep pre-requisite: relative symlink
#    (absolute path fails inside container because host path /home/... is not mounted)
(cd "$COPPELIA_DIR" && ln -sf libcoppeliaSim.so libcoppeliaSim.so.1)

# 6. Verify
test -f "$COPPELIA_DIR/coppeliaSim.sh"
test -f "$COPPELIA_DIR/system/usrset.txt"
test -L "$COPPELIA_DIR/libcoppeliaSim.so.1"
echo "✓ CoppeliaSim installed at $COPPELIA_DIR"

# 7. Offer to clean up legacy ~/CoppeliaSim install
if [ -d "$HOME/CoppeliaSim" ]; then
    OLD_SIZE=$(du -sh "$HOME/CoppeliaSim" 2>/dev/null | cut -f1)
    echo ""
    echo "Detected legacy install: $HOME/CoppeliaSim (${OLD_SIZE})"
    read -rp "Delete it to reclaim disk? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/CoppeliaSim"
        echo "✓ Removed $HOME/CoppeliaSim"
    else
        echo "  Kept $HOME/CoppeliaSim (you can remove it manually later)"
    fi
fi

# 8. Next steps
cat <<EOF

Next:
  docker compose -f docker/docker-compose.headless.yaml up -d

(COPPELIASIM_ROOT env var no longer needs to be set; compose defaults to
$COPPELIA_DIR.)
EOF
