#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# CappyCloud Session Worktree Setup
#
# Called via `docker exec` by the API when a new conversation
# starts inside a persistent environment container.
# Creates an isolated git worktree for the session so the agent
# operates in a clean, branch-isolated directory while sharing
# the repo's object store with all other sessions in this container.
#
# Usage: /session_start.sh <session_id> <worktree_path>
#   session_id    — short identifier used as the git branch name
#   worktree_path — absolute path inside the container (e.g. /workspace/sessions/abc123)
# ──────────────────────────────────────────────────────────────
set -euo pipefail

SESSION_ID="${1:?SESSION_ID (arg 1) is required}"
WORKTREE_PATH="${2:?WORKTREE_PATH (arg 2) is required}"
MAIN_REPO="/workspace/main"
BRANCH="cappy/session/${SESSION_ID}"

echo "Setting up worktree for session '${SESSION_ID}' at '${WORKTREE_PATH}'..."

# ── Idempotent: skip if worktree already exists ───────────────
if [ -d "${WORKTREE_PATH}" ] && { [ -f "${WORKTREE_PATH}/.git" ] || [ -d "${WORKTREE_PATH}/.git" ]; }; then
    echo "Worktree already exists at ${WORKTREE_PATH} — skipping creation."
    exit 0
fi

mkdir -p "$(dirname "${WORKTREE_PATH}")"

# ── Create worktree on a dedicated branch ────────────────────
# A named branch lets the agent commit changes that can later be
# pushed or reviewed as a PR, exactly like Claude Code cloud.
cd "${MAIN_REPO}"

if git worktree add "${WORKTREE_PATH}" -b "${BRANCH}" 2>/dev/null; then
    echo "Worktree created on new branch '${BRANCH}'."
else
    # Branch already exists (container restarted, session recovered) — detach
    git worktree add "${WORKTREE_PATH}" --detach 2>&1
    echo "Worktree created in detached state (branch '${BRANCH}' already exists)."
fi

# ── Inject agent instructions into the worktree ──────────────
# CLAUDE.md is not committed — stays untracked inside the container.
if [ -f /app/CLAUDE.md ]; then
    cp /app/CLAUDE.md "${WORKTREE_PATH}/CLAUDE.md"
    echo "CLAUDE.md injected into ${WORKTREE_PATH}."
fi

echo "Session worktree ready: ${WORKTREE_PATH}"
