#!/bin/bash
# link-setup.sh
# Creates symlinks and copies files that are normally done by repo sync
# Run this AFTER repo sync and git2-setup.sh

set -e

# Determine workspace root (works from both workspace root and .repo/local_manifests/)
if [[ -d ".repo" ]]; then
    ROOT_DIR="$(pwd)"
elif [[ -d "../../.repo" ]]; then
    # Running from .repo/local_manifests/
    ROOT_DIR="$(cd ../.. && pwd)"
else
    echo "Error: Not in a repo workspace"
    exit 1
fi

echo "Setting up links in: $ROOT_DIR"
cd "$ROOT_DIR"

# ============================================================
# Helper functions
# ============================================================

create_link() {
    local src="$1"
    local dest="$2"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        echo "  Skip: $dest (already exists)"
        return
    fi

    if [ ! -e "$src" ]; then
        echo "  Skip: $dest (source not found: $src)"
        return
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$dest")"

    # Calculate relative path from dest directory to src
    local dest_dir="$(dirname "$dest")"
    local rel_src="$(realpath --relative-to="$dest_dir" "$src")"

    ln -s "$rel_src" "$dest"
    echo "  Link: $dest -> $rel_src"
}

copy_file() {
    local src="$1"
    local dest="$2"

    if [ -e "$dest" ]; then
        echo "  Skip: $dest (already exists)"
        return
    fi

    if [ ! -e "$src" ]; then
        echo "  Skip: $dest (source not found: $src)"
        return
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$dest")"

    cp "$src" "$dest"
    echo "  Copy: $src -> $dest"
}

# ============================================================
# build/bazel links
# ============================================================
echo ""
echo "=== build/bazel links ==="
create_link "build/bazel/bazel.WORKSPACE" "WORKSPACE"
create_link "build/bazel/bazel.BUILD" "BUILD"

# ============================================================
# build/make links (project path: build/make)
# ============================================================
echo ""
echo "=== build/make links ==="
create_link "build/make/CleanSpec.mk" "build/CleanSpec.mk"
create_link "build/make/buildspec.mk.default" "build/buildspec.mk.default"
create_link "build/make/core" "build/core"
create_link "build/make/envsetup.sh" "build/envsetup.sh"
create_link "build/make/target" "build/target"
create_link "build/make/tools" "build/tools"

# ============================================================
# build/soong links
# ============================================================
echo ""
echo "=== build/soong links ==="
create_link "build/soong/root.bp" "Android.bp"
create_link "build/soong/bootstrap.bash" "bootstrap.bash"

# ============================================================
# trusty links
# ============================================================
echo ""
echo "=== trusty links ==="
create_link "trusty/host/common/bazel/WORKSPACE.bazel" "trusty/WORKSPACE.bazel"
create_link "trusty/host/common/bazel/bazelrc" "trusty/.bazelrc"

# ============================================================
# trusty copyfile
# ============================================================
echo ""
echo "=== trusty copyfile ==="
copy_file "trusty/vendor/google/aosp/lk_inc.mk" "lk_inc.mk"

echo ""
echo "=== Link setup complete ==="
