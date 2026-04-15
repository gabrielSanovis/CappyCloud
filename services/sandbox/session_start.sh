#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# /session_start.sh — Cria um git worktree por sessão de conversa
#
# Uso:  /session_start.sh <env_slug> <session_id> <worktree_path>
#
# Chamado via `docker exec` pelo EnvironmentManager sempre que uma
# nova conversa começa.  O worktree é criado a partir de /repos/<env_slug>.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

ENV_SLUG="${1:?Usage: session_start.sh <env_slug> <session_id> <worktree_path>}"
SESSION_ID="${2:?Usage: session_start.sh <env_slug> <session_id> <worktree_path>}"
WORKTREE_PATH="${3:?Usage: session_start.sh <env_slug> <session_id> <worktree_path>}"
MAIN_REPO="/repos/${ENV_SLUG}"

echo "[session_start] env=${ENV_SLUG}  session=${SESSION_ID}  worktree=${WORKTREE_PATH}"

mkdir -p "$(dirname "$WORKTREE_PATH")"

# Se o worktree já existe, apenas valida
if [ -d "$WORKTREE_PATH/.git" ] || [ -f "$WORKTREE_PATH/.git" ]; then
    echo "[session_start] Worktree já existe — reutilizando."
    exit 0
fi

if [ -d "$MAIN_REPO/.git" ]; then
    # Garante que HEAD aponta para um commit válido antes de criar o worktree.
    if ! git -C "$MAIN_REPO" rev-parse HEAD >/dev/null 2>&1; then
        echo "[session_start] Repo sem commits — criando commit inicial..."
        git -C "$MAIN_REPO" config user.email "agent@cappycloud.local"
        git -C "$MAIN_REPO" config user.name "CappyCloud Agent"
        git -C "$MAIN_REPO" commit --allow-empty -m "init"
    fi

    BRANCH="session/$SESSION_ID"
    echo "[session_start] Criando worktree git: branch=$BRANCH"
    git -C "$MAIN_REPO" worktree add -b "$BRANCH" "$WORKTREE_PATH" 2>&1 \
        || git -C "$MAIN_REPO" worktree add "$WORKTREE_PATH" 2>&1
else
    echo "[session_start] Sem repo git em $MAIN_REPO — criando directório vazio."
    mkdir -p "$WORKTREE_PATH"
fi

echo "[session_start] OK"
