#!/bin/bash
#
# populate-proprietary.sh
#
# Standalone helper to copy the blobs listed in proprietary-files.txt out
# of a mounted/extracted SM-G389F stock firmware tree and into the
# vendor/samsung/xcover3velte/proprietary/ layout that xcover3velte-vendor.mk
# expects.
#
# This does the same job as LineageOS's extract-files.sh/setup-makefiles.sh,
# but works standalone - useful now, before you have a full repo-synced
# LineageOS source tree to run the real tooling in.
#
# Usage:
#   ./populate-proprietary.sh /path/to/mounted/system [output_dir]
#
#   /path/to/mounted/system  - root of your extracted/mounted stock system
#                               image (the directory that directly contains
#                               app/, bin/, lib/, vendor/, etc. - i.e. what
#                               would be /system on the real device)
#   output_dir                - where to write the proprietary/ folder
#                               (default: ./proprietary)
#
# After running, copy the resulting proprietary/ folder into
# vendor/samsung/xcover3velte/proprietary/ in your synced LineageOS tree.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROP_LIST="${SCRIPT_DIR}/proprietary-files.txt"

if [ $# -lt 1 ]; then
    echo "Usage: $0 /path/to/mounted/system [output_dir]"
    exit 1
fi

SRC="$1"
OUT="${2:-${SCRIPT_DIR}/proprietary}"

if [ ! -d "$SRC" ]; then
    echo "Error: source directory '$SRC' does not exist"
    exit 1
fi

if [ ! -f "$PROP_LIST" ]; then
    echo "Error: proprietary-files.txt not found next to this script (expected at $PROP_LIST)"
    exit 1
fi

mkdir -p "$OUT"

found=0
missing=0
missing_list=()

while IFS= read -r raw_line || [ -n "$raw_line" ]; do
    line="$(echo "$raw_line" | sed 's/[[:space:]]*$//')"

    # skip blank lines and full-line comments
    [ -z "$line" ] && continue
    case "$line" in
        \#*) continue ;;
    esac

    # strip any trailing inline comment (format: "path  # comment")
    line="$(echo "$line" | sed 's/[[:space:]]*#.*$//')"
    [ -z "$line" ] && continue

    if [[ "$line" == *:* ]]; then
        src_rel="${line%%:*}"
        dst_rel="${line#*:}"
    else
        src_rel="$line"
        dst_rel="$line"
    fi

    src_path="${SRC}/${src_rel}"
    out_path="${OUT}/${src_rel}"

    if [ -f "$src_path" ]; then
        mkdir -p "$(dirname "$out_path")"
        cp -p "$src_path" "$out_path"
        found=$((found + 1))
    else
        missing=$((missing + 1))
        missing_list+=("$src_rel")
    fi
done < "$PROP_LIST"

echo ""
echo "=========================================="
echo "Found and copied: $found"
echo "Missing:          $missing"
echo "=========================================="

if [ "$missing" -gt 0 ]; then
    echo ""
    echo "The following files were NOT found under $SRC :"
    for f in "${missing_list[@]}"; do
        echo "  !! $f"
    done
    echo ""
    echo "If any of these are genuinely present on your device but under a"
    echo "different path, check manually and copy them in by hand, or update"
    echo "proprietary-files.txt with the corrected path (same convention we"
    echo "used earlier: 'real/source/path:intended/dest/path' if they differ)."
    echo ""
    echo "If any are confirmed genuinely absent, they can stay commented out"
    echo "in proprietary-files.txt like the entries already marked that way."
fi

echo ""
echo "Output written to: $OUT"
echo "Copy this folder to vendor/samsung/xcover3velte/proprietary/ in your"
echo "synced LineageOS source tree."
