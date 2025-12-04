#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Checking for new kernel versions..."

# Function to get the latest version for a major.minor series
get_latest_kernel_version() {
    local major_minor=$1
    local url="https://www.kernel.org/releases.json"

    # Fetch kernel releases and find latest for the series
    curl -s "$url" | jq -r \
        --arg series "$major_minor" \
        '.releases[] | select(.version | startswith($series)) | .version' | \
        sort -V | tail -n1
}

# Function to get current version from flake.nix
get_current_version() {
    local variant=$1
    grep -A 5 "# $variant kernel" flake.nix | \
        grep 'version = ' | \
        sed 's/.*version = "\(.*\)";/\1/'
}

# Function to get hash for a kernel version
get_kernel_hash() {
    local version=$1
    local major=$(echo "$version" | cut -d. -f1)
    local url="https://cdn.kernel.org/pub/linux/kernel/v${major}.x/linux-${version}.tar.xz"

    echo "  Fetching hash for $version..." >&2
    nix-prefetch-url "$url" 2>/dev/null
}

# Function to update flake.nix with new version
update_flake() {
    local variant=$1
    local old_version=$2
    local new_version=$3
    local new_hash=$4

    echo "  Updating flake.nix..." >&2

    # Create a temporary file
    local tmp_file=$(mktemp)

    # Read the file and update the version and hash
    awk -v variant="$variant" \
        -v old_version="$old_version" \
        -v new_version="$new_version" \
        -v new_hash="sha256-$new_hash" '
    {
        # Update version
        if ($0 ~ /version = "'"$old_version"'"/) {
            gsub(/"'"$old_version"'"/, "\"" new_version "\"")
        }
        # Update URL
        if ($0 ~ /linux-'"$old_version"'\.tar\.xz/) {
            gsub(/linux-'"$old_version"'\.tar\.xz/, "linux-" new_version ".tar.xz")
        }
        # Update hash (look for the line after the URL)
        if (prev_line ~ /linux-'"$old_version"'\.tar\.xz/ || prev_line ~ /linux-'"$new_version"'\.tar\.xz/) {
            if ($0 ~ /hash = /) {
                sub(/hash = ".*"/, "hash = \"" new_hash "\"")
            }
        }
        print
        prev_line = $0
    }
    ' flake.nix > "$tmp_file"

    mv "$tmp_file" flake.nix
}

# Check LTS kernel (6.6.x series)
echo ""
echo "📦 Checking LTS kernel (6.6.x)..."
LTS_CURRENT=$(get_current_version "LTS")
LTS_LATEST=$(get_latest_kernel_version "6.6")

if [ -z "$LTS_LATEST" ]; then
    echo -e "${RED}❌ Could not fetch latest LTS version${NC}"
    LTS_UPDATED=false
else
    echo "  Current: $LTS_CURRENT"
    echo "  Latest:  $LTS_LATEST"

    if [ "$LTS_CURRENT" != "$LTS_LATEST" ]; then
        echo -e "${GREEN}✨ New LTS version available!${NC}"
        echo "  Getting hash for $LTS_LATEST..."
        LTS_HASH=$(get_kernel_hash "$LTS_LATEST")
        echo "  Hash: sha256-$LTS_HASH"
        update_flake "LTS" "$LTS_CURRENT" "$LTS_LATEST" "$LTS_HASH"
        LTS_UPDATED=true
        echo -e "${GREEN}✅ Updated LTS kernel to $LTS_LATEST${NC}"
    else
        echo -e "${YELLOW}✓ LTS kernel is up to date${NC}"
        LTS_UPDATED=false
    fi
fi

# Check Latest kernel (6.12.x series)
echo ""
echo "📦 Checking Latest kernel (6.12.x)..."
LATEST_CURRENT=$(get_current_version "Latest")
LATEST_LATEST=$(get_latest_kernel_version "6.12")

if [ -z "$LATEST_LATEST" ]; then
    echo -e "${RED}❌ Could not fetch latest kernel version${NC}"
    LATEST_UPDATED=false
else
    echo "  Current: $LATEST_CURRENT"
    echo "  Latest:  $LATEST_LATEST"

    if [ "$LATEST_CURRENT" != "$LATEST_LATEST" ]; then
        echo -e "${GREEN}✨ New kernel version available!${NC}"
        echo "  Getting hash for $LATEST_LATEST..."
        LATEST_HASH=$(get_kernel_hash "$LATEST_LATEST")
        echo "  Hash: sha256-$LATEST_HASH"
        update_flake "Latest" "$LATEST_CURRENT" "$LATEST_LATEST" "$LATEST_HASH"
        LATEST_UPDATED=true
        echo -e "${GREEN}✅ Updated Latest kernel to $LATEST_LATEST${NC}"
    else
        echo -e "${YELLOW}✓ Latest kernel is up to date${NC}"
        LATEST_UPDATED=false
    fi
fi

# Output results
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$LTS_UPDATED" = true ] || [ "$LATEST_UPDATED" = true ]; then
    echo -e "${GREEN}🎉 Kernel updates available!${NC}"
    echo ""

    if [ "$LTS_UPDATED" = true ]; then
        echo "  • LTS: $LTS_CURRENT → $LTS_LATEST"
    fi

    if [ "$LATEST_UPDATED" = true ]; then
        echo "  • Latest: $LATEST_CURRENT → $LATEST_LATEST"
    fi

    echo ""
    echo "updated=true" >> "$GITHUB_OUTPUT" 2>/dev/null || true

    # Create a summary for GitHub Actions
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
        {
            echo "## 🎉 Kernel Updates Available"
            echo ""
            echo "| Variant | Old Version | New Version |"
            echo "|---------|-------------|-------------|"
            [ "$LTS_UPDATED" = true ] && echo "| LTS | $LTS_CURRENT | $LTS_LATEST |"
            [ "$LATEST_UPDATED" = true ] && echo "| Latest | $LATEST_CURRENT | $LATEST_LATEST |"
        } >> "$GITHUB_STEP_SUMMARY"
    fi

    exit 0
else
    echo -e "${GREEN}✅ All kernels are up to date${NC}"
    echo "updated=false" >> "$GITHUB_OUTPUT" 2>/dev/null || true

    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
        echo "## ✅ All kernels are up to date" >> "$GITHUB_STEP_SUMMARY"
    fi

    exit 0
fi
