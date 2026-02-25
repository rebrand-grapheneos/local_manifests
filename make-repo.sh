#!/bin/bash
#
# make-repo.sh - Generate local_manifests/default.xml from git2 projects
#
# Usage:
#   make-repo.sh <tag-name>
#
# Example:
#   make-repo.sh 2025110800
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[OK]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Check argument
if [[ -z "$1" ]]; then
    echo "Usage: $0 <tag-name>"
    echo "Example: $0 2025110800"
    exit 1
fi

TAG_NAME="$1"

# Determine workspace root (works from anywhere in the repo)
find_workspace() {
    local dir="$(pwd)"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.repo" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    log_error "Not in a repo workspace"
    exit 1
}

WORKSPACE=$(find_workspace)
OUTPUT_FILE="$WORKSPACE/.repo/local_manifests/default.xml"

log_info "Generating manifest for tag: $TAG_NAME"
log_info "Workspace: $WORKSPACE"

# Find all projects with .git2 folder
find_git2_projects() {
    find "$WORKSPACE" -type d -name ".git2" 2>/dev/null | \
        grep -v "\.repo" | \
        while read -r git2_dir; do
            dirname "$git2_dir"
        done | sort
}

# Map project path to project name (based on GrapheneOS naming convention)
get_project_name() {
    local path="$1"
    case "$path" in
        "build/make")
            echo "platform_build"
            ;;
        "frameworks/base")
            echo "platform_frameworks_base"
            ;;
        "packages/apps/"*)
            local app_name="${path#packages/apps/}"
            echo "platform_packages_apps_${app_name}"
            ;;
        "script")
            echo "script"
            ;;
        *)
            # Default: replace / with _
            echo "${path//\//_}"
            ;;
    esac
}

# Generate XML
generate_xml() {
    cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <!-- Rebrand Graphene OS Custom Manifest -->

  <!-- Remote for Rebrand Graphene OS git2 repositories (SSH for private repos) -->
  <remote name="rebrand-grapheneos" fetch="git@github.com:rebrand-grapheneos/" />

EOF

    while IFS= read -r project_dir; do
        local project_path="${project_dir#$WORKSPACE/}"
        local git2_dir="$project_dir/.git2"

        if [[ -d "$git2_dir/.git" ]]; then
            cd "$git2_dir"

            # Get commit hash
            local revision=$(git log -1 --format=%H 2>/dev/null)

            if [[ -n "$revision" ]]; then
                local project_name=$(get_project_name "$project_path")

                log_info "Found: $project_path -> $project_name ($revision)"

                cat << EOF
  <remove-project name="$project_name" />
  <project path="$project_path" name="$project_name" remote="rebrand-grapheneos" revision="$revision" upstream="refs/tags/$TAG_NAME" dest-branch="refs/tags/$TAG_NAME"/>

EOF
            fi

            cd "$WORKSPACE"
        fi
    done < <(find_git2_projects)

    echo "</manifest>"
}

# Generate and save
log_info "Scanning git2 projects..."
generate_xml > "$OUTPUT_FILE"

log_success "Generated: $OUTPUT_FILE"
log_info "Done!"
