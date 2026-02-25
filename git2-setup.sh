#!/bin/bash
#
# git2-setup.sh - Run git2 start on all modified projects
#
# This script is called by setup.sh after repo sync.
# It initializes git2 for all projects listed in manifest.xml that use git2.
#

set -e

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

# Determine workspace root
if [[ -d ".repo" ]]; then
    WORKSPACE="$(pwd)"
elif [[ -d "../../.repo" ]]; then
    # Running from .repo/local_manifests/
    WORKSPACE="$(cd ../.. && pwd)"
else
    log_error "Not in a repo workspace"
    exit 1
fi

log_info "Running git2 start on all projects..."
log_info "Workspace: $WORKSPACE"
echo ""

# Find all projects with .git2config (indicating git2 repo)
cd "$WORKSPACE"

SUCCESS_COUNT=0
FAIL_COUNT=0

while IFS= read -r git2config; do
    project_dir=$(dirname "$git2config")
    project_name="${project_dir#$WORKSPACE/}"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log_info "Project: $project_name"

    cd "$project_dir"

    # Check if git2 start is needed
    if [[ -d ".git2" ]]; then
        log_warn "  .git2 already exists, skipping"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    elif [[ -f "git2.sh" ]]; then
        log_info "  Running git2 start..."
        if ./git2.sh start; then
            log_success "  git2 start complete"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            log_error "  git2 start failed"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        log_warn "  git2.sh not found"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    cd "$WORKSPACE"
done < <(find "$WORKSPACE" -name ".git2config" -type f 2>/dev/null | grep -v "\.repo" | grep -v "/\.git2/")

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ $SUCCESS_COUNT -eq 0 ]] && [[ $FAIL_COUNT -eq 0 ]]; then
    log_info "No git2 projects found"
else
    log_info "Complete: $SUCCESS_COUNT success, $FAIL_COUNT failed"
fi
