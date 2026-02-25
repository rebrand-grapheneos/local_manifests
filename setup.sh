#!/bin/bash
#
# setup.sh - Initialize GrapheneOS workspace with Rebrand Graphene OS
#
# This script transforms the current directory into a GrapheneOS workspace.
# After running, git operations are done in .repo/local_manifests/ folder.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Read TAG
if [[ ! -f "$SCRIPT_DIR/TAG" ]]; then
    log_error "TAG file not found"
    exit 1
fi

TAG_NAME=$(cat "$SCRIPT_DIR/TAG" | tr -d '[:space:]')

if [[ -z "$TAG_NAME" ]]; then
    log_error "TAG is empty"
    exit 1
fi

log_info "Rebrand Graphene OS Setup"
log_info "  Tag: $TAG_NAME"
log_info "  Directory: $SCRIPT_DIR"
echo ""

# Check if already initialized
if [[ -d "$SCRIPT_DIR/.repo" ]]; then
    log_error ".repo already exists. Setup already completed?"
    exit 1
fi

# Step 1: repo init
log_info "Step 1: Initializing repo with tag $TAG_NAME..."
repo init -u https://github.com/GrapheneOS/platform_manifest.git -b "refs/tags/$TAG_NAME"
log_success "repo init complete"

# Step 2: Move all files to .repo/local_manifests/ (becomes git repo)
log_info "Step 2: Moving rebrand-grapheneos-git to .repo/local_manifests/..."
mkdir -p .repo/local_manifests

# Move .git folder
if [[ -d "$SCRIPT_DIR/.git" ]]; then
    mv "$SCRIPT_DIR/.git" .repo/local_manifests/
    log_success ".git moved to .repo/local_manifests/"
fi

# Move all rebrand-grapheneos files
for file in setup.sh git2-setup.sh git2-all.sh make-repo.sh TAG default.xml repo-helper.sh link-setup.sh; do
    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        mv "$SCRIPT_DIR/$file" .repo/local_manifests/
    fi
done
log_success "Files moved to .repo/local_manifests/"

echo ""
log_success "=========================================="
log_success "Setup complete!"
log_success "=========================================="
echo ""
log_info "Workspace: $SCRIPT_DIR"
echo ""
log_info "Next steps:"
log_info "  1. repo sync -j\$(nproc)"
log_info "  2. .repo/local_manifests/git2-setup.sh"
echo ""
log_info "Git operations (for rebrand-grapheneos-git):"
log_info "  cd .repo/local_manifests"
log_info "  git status"
log_info "  git add default.xml TAG"
log_info "  git commit -m 'message'"
log_info "  git push origin main"
echo ""
log_info "Build commands:"
log_info "  source build/envsetup.sh"
log_info "  lunch <device>"
log_info "  m"
