#!/bin/bash
#
# git2-all.sh - Run git2 commands on all projects with .git2 folder
#
# Commands:
#   git2-all push       Run git2 push on all projects
#   git2-all pull       Run git2 pull on all projects
#   git2-all git <cmd>  Run git <cmd> in each project's .git2 folder
#   git2-all reset      Revert all changes in projects except .git2 folder
#   git2-all status     Show status of all .git2 projects
#   git2-all list       List all projects with .git2 folder
#
# Examples:
#   git2-all.sh push                    # Sync all projects to .git2
#   git2-all.sh pull                    # Sync all .git2 to projects
#   git2-all.sh git status              # git status in all .git2 folders
#   git2-all.sh git add -A              # git add -A in all .git2 folders
#   git2-all.sh git commit -m "msg"     # git commit in all .git2 folders
#   git2-all.sh git push                # git push in all .git2 folders
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_project() { echo -e "${CYAN}[PROJECT]${NC} $1"; }

# Determine workspace root
find_workspace() {
    if [[ -d ".repo" ]]; then
        echo "$(pwd)"
    elif [[ -d "../../.repo" ]]; then
        # Running from .repo/local_manifests/
        cd ../.. && pwd
    else
        log_error "Not in a repo workspace"
        exit 1
    fi
}

WORKSPACE=$(find_workspace)

# Find all projects with .git2 folder
find_git2_projects() {
    find "$WORKSPACE" -type d -name ".git2" 2>/dev/null | \
        grep -v "\.repo" | \
        while read -r git2_dir; do
            dirname "$git2_dir"
        done | sort
}

show_help() {
    cat << 'EOF'
git2-all - Run git2 commands on all projects with .git2 folder

Usage:
  git2-all.sh <command> [arguments]

Commands:
  push              Run git2 push on all projects (sync project -> .git2)
  pull              Run git2 pull on all projects (sync .git2 -> project)
  reset             Revert all changes in projects except .git2 folder
  git <cmd>         Run git <cmd> in each project's .git2 folder
  status            Show git status of all .git2 folders
  list              List all projects with .git2 folder
  help              Show this help message

Examples:
  git2-all.sh push                    # Sync all projects to .git2
  git2-all.sh pull                    # Sync all .git2 to projects
  git2-all.sh git status              # git status in all .git2 folders
  git2-all.sh git add -A              # git add -A in all .git2 folders
  git2-all.sh git commit -m "Update"  # git commit in all .git2 folders
  git2-all.sh git push                # git push in all .git2 folders
  git2-all.sh git log --oneline -3    # git log in all .git2 folders
EOF
}

# Run git2 command (push/pull) on all projects
cmd_git2() {
    local git2_cmd="$1"
    local success_count=0
    local fail_count=0

    log_info "Running git2 $git2_cmd on all projects..."
    echo ""

    while IFS= read -r project_dir; do
        local project_name="${project_dir#$WORKSPACE/}"

        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log_project "$project_name"

        cd "$project_dir"

        if [[ -f ".git2/git2.sh" ]]; then
            if .git2/git2.sh "$git2_cmd"; then
                ((success_count++))
            else
                log_error "git2 $git2_cmd failed"
                ((fail_count++))
            fi
        else
            log_warn ".git2/git2.sh not found, skipping"
            ((fail_count++))
        fi

        cd "$WORKSPACE"
        echo ""
    done < <(find_git2_projects)

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log_info "git2 $git2_cmd complete: $success_count success, $fail_count failed"
}

# Run git command in all .git2 folders
cmd_git() {
    local success_count=0
    local fail_count=0

    log_info "Running git $* in all .git2 folders..."
    echo ""

    while IFS= read -r project_dir; do
        local project_name="${project_dir#$WORKSPACE/}"
        local git2_dir="$project_dir/.git2"

        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log_project "$project_name/.git2"

        if [[ -d "$git2_dir/.git" ]]; then
            cd "$git2_dir"
            if git "$@"; then
                ((success_count++))
            else
                log_warn "git command returned non-zero"
                ((fail_count++))
            fi
            cd "$WORKSPACE"
        else
            log_warn ".git2/.git not found (not initialized), skipping"
            ((fail_count++))
        fi

        echo ""
    done < <(find_git2_projects)

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log_info "git $1 complete: $success_count success, $fail_count failed"
}

# Show status of all .git2 folders
cmd_status() {
    log_info "Status of all .git2 folders..."
    echo ""

    while IFS= read -r project_dir; do
        local project_name="${project_dir#$WORKSPACE/}"
        local git2_dir="$project_dir/.git2"

        if [[ -d "$git2_dir/.git" ]]; then
            cd "$git2_dir"
            local status=$(git status -s 2>/dev/null)
            if [[ -n "$status" ]]; then
                echo -e "${CYAN}$project_name/.git2${NC}"
                echo "$status"
                echo ""
            fi
            cd "$WORKSPACE"
        fi
    done < <(find_git2_projects)
}

# Reset all changes in projects except .git2 folder
cmd_reset() {
    local success_count=0
    local fail_count=0

    log_info "Resetting all projects (preserving .git2)..."
    echo ""

    while IFS= read -r project_dir; do
        local project_name="${project_dir#$WORKSPACE/}"

        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log_project "$project_name"

        cd "$project_dir"

        # Revert tracked file changes, excluding .git2
        local changed_files=$(git diff --name-only 2>/dev/null | grep -v '^\.git2/')
        if [[ -n "$changed_files" ]]; then
            echo "$changed_files" | xargs git checkout -- 2>/dev/null
            echo -e "${GREEN}Reverted:${NC} tracked changes"
        fi

        # Revert staged changes, excluding .git2
        local staged_files=$(git diff --cached --name-only 2>/dev/null | grep -v '^\.git2/')
        if [[ -n "$staged_files" ]]; then
            echo "$staged_files" | xargs git reset HEAD -- 2>/dev/null
            echo "$staged_files" | xargs git checkout -- 2>/dev/null
            echo -e "${GREEN}Reverted:${NC} staged changes"
        fi

        # Remove untracked files, excluding .git2
        local untracked_files=$(git ls-files --others --exclude-standard 2>/dev/null | grep -v '^\.git2/')
        if [[ -n "$untracked_files" ]]; then
            echo "$untracked_files" | xargs rm -f 2>/dev/null
            echo -e "${GREEN}Removed:${NC} untracked files"
        fi

        # Remove empty directories (excluding .git2)
        find . -type d -empty -not -path './.git/*' -not -path './.git2/*' -delete 2>/dev/null

        # Verify clean state (excluding .git2)
        local remaining=$(git status -s 2>/dev/null | grep -v '^\?\? \.git2/' | grep -v '^ M \.git2/' | grep -v '^M  \.git2/')
        if [[ -z "$remaining" ]]; then
            log_success "Clean"
            ((success_count++))
        else
            log_warn "Some changes remain:"
            echo "$remaining"
            ((fail_count++))
        fi

        cd "$WORKSPACE"
        echo ""
    done < <(find_git2_projects)

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log_info "Reset complete: $success_count clean, $fail_count with remaining changes"
}

# List all projects with .git2 folder
cmd_list() {
    log_info "Projects with .git2 folder:"
    echo ""

    while IFS= read -r project_dir; do
        local project_name="${project_dir#$WORKSPACE/}"
        local git2_dir="$project_dir/.git2"

        if [[ -d "$git2_dir/.git" ]]; then
            echo -e "  ${GREEN}[git]${NC} $project_name"
        else
            echo -e "  ${YELLOW}[no-git]${NC} $project_name"
        fi
    done < <(find_git2_projects)
}

# Main
main() {
    local cmd="${1:-}"
    shift || true

    case "$cmd" in
        push)
            cmd_git2 "push"
            ;;
        pull)
            cmd_git2 "pull"
            ;;
        reset)
            cmd_reset
            ;;
        git)
            if [[ $# -eq 0 ]]; then
                log_error "git command requires arguments"
                echo "Usage: git2-all.sh git <command> [args]"
                exit 1
            fi
            cmd_git "$@"
            ;;
        status|st)
            cmd_status
            ;;
        list|ls)
            cmd_list
            ;;
        help|--help|-h)
            show_help
            ;;
        "")
            show_help
            ;;
        *)
            log_error "Unknown command: $cmd"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
