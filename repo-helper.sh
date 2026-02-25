#!/bin/bash
# GrapheneOS repo helper script for tracking changes across multiple git repositories

set -e

# Determine workspace root (works from both workspace root and .repo/local_manifests/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/.repo" ]]; then
    # Running from workspace root
    cd "$SCRIPT_DIR"
elif [[ -d "$SCRIPT_DIR/../../.repo" ]]; then
    # Running from .repo/local_manifests/
    cd "$SCRIPT_DIR/../.."
else
    echo "Error: Not in a repo workspace"
    exit 1
fi

case "${1:-}" in
  status|st)
    # Show changed projects
    echo "=== Changed Projects ==="
    repo status -j8
    ;;

  diff|d)
    # Show diff of changes
    if [ -z "$2" ]; then
      repo diff
    else
      # Specific project
      cd "$2"
      git diff
    fi
    ;;

  list-modified|lm)
    # List all modified files
    echo "=== Modified Files ==="
    for project in $(repo list -p 2>/dev/null); do
      if [ -d "$project" ]; then
        status=$(cd "$project" && git status -s 2>/dev/null)
        if [ -n "$status" ]; then
          echo "$status"
          echo "  in $project"
        fi
      fi
    done | grep -v "^$" || echo "No modifications"
    ;;

  projects|p)
    # List projects with changes
    echo "=== Projects with Changes ==="
    repo forall -c 'if [ -n "$(git status -s)" ]; then echo "$REPO_PATH"; fi'
    ;;

  show|s)
    # Show detailed info for a specific project
    if [ -z "$2" ]; then
      echo "Usage: $0 show <project_path>"
      exit 1
    fi
    cd "$2"
    echo "=== Git Status for $2 ==="
    git status
    echo ""
    echo "=== Recent Commits ==="
    git log --oneline -5
    echo ""
    echo "=== Uncommitted Changes ==="
    git diff --stat
    ;;

  log|l)
    # Show logs for all changed projects
    echo "=== Recent Changes Across All Projects ==="
    repo forall -c 'if [ -n "$(git status -s)" ]; then echo ""; echo "=== $REPO_PATH ==="; git log --oneline -3 --decorate; fi'
    ;;

  graphene|g)
    # GrapheneOS-specific projects only
    echo "=== GrapheneOS-specific Projects Status ==="
    for project in script branding device/google/comet device/google/comet-sepolicy \
                   packages/apps/Updater packages/apps/Auditor \
                   external/hardened_malloc external/vanadium; do
      if [ -d "$project" ]; then
        cd "$project"
        if [ -n "$(git status -s 2>/dev/null)" ]; then
          echo ""
          echo "📁 $project"
          git status -s
        fi
        cd - > /dev/null
      fi
    done
    ;;

  watch|w)
    # Real-time monitoring of changes
    echo "Watching for changes... (Ctrl+C to stop)"
    while true; do
      clear
      echo "=== Last updated: $(date) ==="
      echo ""
      repo forall -c 'git status -s 2>/dev/null | grep -v "^$" && echo "  📁 $REPO_PATH"' 2>/dev/null | grep -v "^$" || echo "No modifications"
      sleep 3
    done
    ;;

  staged)
    # Show staged files
    echo "=== Staged Files ==="
    repo forall -c 'if [ -n "$(git diff --cached --name-only)" ]; then echo ""; echo "📁 $REPO_PATH:"; git diff --cached --name-status; fi'
    ;;

  unstaged)
    # Show unstaged files
    echo "=== Unstaged Files ==="
    repo forall -c 'if [ -n "$(git diff --name-only)" ]; then echo ""; echo "📁 $REPO_PATH:"; git diff --name-status; fi'
    ;;

  summary)
    # Overall repository summary
    echo "╔════════════════════════════════════════════╗"
    echo "║    GrapheneOS Repository Summary           ║"
    echo "╚════════════════════════════════════════════╝"
    echo ""

    total_projects=$(repo list | wc -l)
    modified_projects=$(repo forall -c 'if [ -n "$(git status -s)" ]; then echo "1"; fi' | wc -l)
    total_files=$(repo forall -c 'git status -s | wc -l' | awk '{s+=$1} END {print s}')

    echo "📊 Total Projects: $total_projects"
    echo "📝 Modified Projects: $modified_projects"
    echo "📄 Total Modified Files: $total_files"
    echo ""

    if [ "$modified_projects" -gt 0 ]; then
      echo "Modified Projects:"
      repo forall -c 'if [ -n "$(git status -s)" ]; then count=$(git status -s | wc -l); echo "  • $REPO_PATH ($count files)"; fi'
    fi
    ;;

  branches|b)
    # Show current branch for all projects
    echo "=== Current Branches ==="
    repo forall -c 'echo "$REPO_PATH: $(git branch --show-current)"'
    ;;

  untracked|u)
    # Show untracked files only
    echo "=== Untracked Files ==="
    repo forall -c 'if [ -n "$(git ls-files --others --exclude-standard)" ]; then echo ""; echo "📁 $REPO_PATH:"; git ls-files --others --exclude-standard; fi'
    ;;

  conflicts|c)
    # Show projects with merge conflicts
    echo "=== Projects with Conflicts ==="
    repo forall -c 'if [ -n "$(git diff --name-only --diff-filter=U)" ]; then echo ""; echo "⚠️  $REPO_PATH:"; git diff --name-only --diff-filter=U; fi'
    ;;

  clean-check|cc)
    # Check if repository is clean
    echo "=== Clean Repository Check ==="
    modified=$(repo forall -c 'if [ -n "$(git status -s)" ]; then echo "1"; fi' | wc -l)
    if [ "$modified" -eq 0 ]; then
      echo "✅ Repository is clean - no modifications"
    else
      echo "❌ Repository has modifications in $modified project(s)"
      repo forall -c 'if [ -n "$(git status -s)" ]; then echo "  • $REPO_PATH"; fi'
    fi
    ;;

  stats)
    # Detailed statistics
    echo "╔════════════════════════════════════════════╗"
    echo "║    Detailed Repository Statistics          ║"
    echo "╚════════════════════════════════════════════╝"
    echo ""

    total_projects=$(repo list | wc -l)
    modified_projects=$(repo forall -c 'if [ -n "$(git status -s)" ]; then echo "1"; fi' | wc -l)
    staged=$(repo forall -c 'git diff --cached --name-only | wc -l' | awk '{s+=$1} END {print s}')
    unstaged=$(repo forall -c 'git diff --name-only | wc -l' | awk '{s+=$1} END {print s}')
    untracked=$(repo forall -c 'git ls-files --others --exclude-standard | wc -l' | awk '{s+=$1} END {print s}')

    echo "Total Projects: $total_projects"
    echo "Modified Projects: $modified_projects"
    echo ""
    echo "File Status:"
    echo "  ✓ Staged: $staged"
    echo "  ~ Unstaged: $unstaged"
    echo "  ? Untracked: $untracked"
    echo "  Total: $((staged + unstaged + untracked))"
    ;;

  help|h|*)
    cat << 'EOF'
🔧 GrapheneOS Repo Helper - Multi-repository Management Tool

Usage: ./repo-helper.sh <command> [arguments]

Commands:
  status, st          Show repo status (changed projects)
  diff, d [path]      Show diff (all or specific project)
  list-modified, lm   List all modified files
  projects, p         List projects with changes
  show, s <path>      Show detailed info for a project
  log, l              Show recent commits in changed projects
  graphene, g         Show GrapheneOS-specific projects only
  watch, w            Watch for changes in real-time (auto-refresh)
  staged              Show staged files only
  unstaged            Show unstaged files only
  untracked, u        Show untracked files only
  branches, b         Show current branch for all projects
  conflicts, c        Show projects with merge conflicts
  clean-check, cc     Check if repository is clean
  summary             Show overall repository summary
  stats               Show detailed statistics
  help, h             Show this help message

Examples:
  ./repo-helper.sh summary              # Quick overview
  ./repo-helper.sh graphene             # Check GrapheneOS-specific changes
  ./repo-helper.sh show device/google/comet  # Detailed project status
  ./repo-helper.sh watch                # Real-time monitoring
  ./repo-helper.sh staged               # See what's ready to commit
  ./repo-helper.sh clean-check          # Verify clean state before build

Tips:
  - Use 'summary' for quick status check
  - Use 'graphene' to focus on custom GrapheneOS code
  - Use 'watch' to monitor changes while working
  - Use 'clean-check' before starting builds
EOF
    ;;
esac
