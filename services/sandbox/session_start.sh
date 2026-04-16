#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# /session_start.sh — Cria um git worktree por sessão de conversa
#
# Uso:  /session_start.sh <env_slug> <session_id> <worktree_path> [base_branch] [branch_name]
#
# Chamado via `docker exec` pelo EnvironmentManager sempre que uma
# nova conversa começa.  O worktree é criado a partir de /repos/<env_slug>,
# na branch BASE_BRANCH (padrão: HEAD do clone principal).
#
# BRANCH_NAME (5º arg) é o nome canónico da branch da sessão — ex.:
#   cappy/autosystem3/a1b2c3d4e5f6
# Quando não fornecido usa-se o legacy <env_slug>_<session_id>.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

ENV_SLUG="${1:?Usage: session_start.sh <env_slug> <session_id> <worktree_path> [base_branch] [branch_name]}"
SESSION_ID="${2:?Usage: session_start.sh <env_slug> <session_id> <worktree_path> [base_branch] [branch_name]}"
WORKTREE_PATH="${3:?Usage: session_start.sh <env_slug> <session_id> <worktree_path> [base_branch] [branch_name]}"
BASE_BRANCH="${4:-}"
# Nome canónico da branch — fornecido pelo servidor a partir do DB.
# Legacy fallback: <env_slug>_<session_id>
BRANCH_NAME="${5:-${ENV_SLUG}_${SESSION_ID}}"
MAIN_REPO="/repos/${ENV_SLUG}"

echo "[session_start] env=${ENV_SLUG}  session=${SESSION_ID}  worktree=${WORKTREE_PATH}  base=${BASE_BRANCH:-HEAD}  branch=${BRANCH_NAME}"

mkdir -p "$(dirname "$WORKTREE_PATH")"

# Se o worktree já existe, apenas valida
if [ -d "$WORKTREE_PATH/.git" ] || [ -f "$WORKTREE_PATH/.git" ]; then
    echo "[session_start] Worktree já existe — reutilizando."
    exit 0
fi

if [ -d "$MAIN_REPO/.git" ]; then
    # ── Recuperação: se o repo não tem remote, o clone inicial falhou ──────────
    REMOTE_URL=$(git -C "$MAIN_REPO" remote get-url origin 2>/dev/null || true)
    if [ -z "$REMOTE_URL" ] && [ -n "${WORKSPACE_REPOS:-}" ]; then
        # Encontra a URL deste slug no WORKSPACE_REPOS
        FOUND_URL=""
        IFS=',' read -ra _REPOS <<< "${WORKSPACE_REPOS}"
        for _r in "${_REPOS[@]}"; do
            _r=$(echo "${_r}" | tr -d '[:space:]')
            _slug=$(basename "${_r}" | sed 's/\.git$//')
            if [ "${_slug}" = "${ENV_SLUG}" ]; then
                FOUND_URL="${_r}"
                break
            fi
        done

        if [ -n "${FOUND_URL}" ]; then
            echo "[session_start] Clone inicial falhou — tentando recuperar agora..."

            if [ -n "${GIT_AUTH_TOKEN:-}" ]; then
                AUTH_REPO=$(echo "${FOUND_URL}" | \
                    sed "s|https://dev.azure.com|https://pat:${GIT_AUTH_TOKEN}@dev.azure.com|" | \
                    sed "s|https://github.com|https://x-token:${GIT_AUTH_TOKEN}@github.com|")
            else
                AUTH_REPO="${FOUND_URL}"
            fi
            BRANCH="${WORKSPACE_BRANCH:-main}"

            [ -f "$MAIN_REPO/CLAUDE.md" ] && cp "$MAIN_REPO/CLAUDE.md" /tmp/_claude_md_backup || true
            rm -rf "$MAIN_REPO/.git"
            if git clone --depth=1 --branch "$BRANCH" "$AUTH_REPO" "$MAIN_REPO" 2>&1 || \
               git clone --depth=1 "$AUTH_REPO" "$MAIN_REPO" 2>&1; then
                echo "[session_start] Recuperação do clone concluída."
            else
                echo "[session_start] AVISO: recuperação do clone falhou — repo vazio."
                git -C "$MAIN_REPO" init -b main 2>/dev/null || git -C "$MAIN_REPO" init
            fi
            [ -f /tmp/_claude_md_backup ] && cp /tmp/_claude_md_backup "$MAIN_REPO/CLAUDE.md" && rm /tmp/_claude_md_backup || true
        fi
    fi

    # Garante que HEAD aponta para um commit válido antes de criar o worktree.
    if ! git -C "$MAIN_REPO" rev-parse HEAD >/dev/null 2>&1; then
        echo "[session_start] Repo sem commits — criando commit inicial..."
        git -C "$MAIN_REPO" config user.email "agent@cappycloud.local"
        git -C "$MAIN_REPO" config user.name "CappyCloud Agent"
        git -C "$MAIN_REPO" commit --allow-empty -m "init"
    fi

    # Nome da branch vem do 5º arg (canónico, definido no DB).
    BRANCH="${BRANCH_NAME}"

    if [ -n "${BASE_BRANCH}" ]; then
        # Garante que a branch base existe localmente (pode ser remota)
        if ! git -C "$MAIN_REPO" rev-parse --verify "${BASE_BRANCH}" >/dev/null 2>&1; then
            echo "[session_start] Buscando branch base remota: ${BASE_BRANCH}..."
            git -C "$MAIN_REPO" fetch origin "${BASE_BRANCH}:${BASE_BRANCH}" 2>&1 \
                || echo "[session_start] AVISO: fetch de ${BASE_BRANCH} falhou — usando HEAD."
        fi

        echo "[session_start] Criando worktree git: branch=${BRANCH} a partir de ${BASE_BRANCH}"
        git -C "$MAIN_REPO" worktree add -b "$BRANCH" "$WORKTREE_PATH" "$BASE_BRANCH" 2>&1 \
            || git -C "$MAIN_REPO" worktree add "$WORKTREE_PATH" 2>&1
    else
        echo "[session_start] Criando worktree git: branch=${BRANCH} a partir de HEAD"
        git -C "$MAIN_REPO" worktree add -b "$BRANCH" "$WORKTREE_PATH" 2>&1 \
            || git -C "$MAIN_REPO" worktree add "$WORKTREE_PATH" 2>&1
    fi
else
    echo "[session_start] Sem repo git em $MAIN_REPO — criando directório vazio."
    mkdir -p "$WORKTREE_PATH"
fi

# ── Injeta CLAUDE.md no worktree ─────────────────────────────
# openclaude usa working_directory=worktree; garante que o CLAUDE.md
# esteja presente diretamente no worktree, não só no repo principal.
if [ -f /app/CLAUDE.md ]; then
    cp /app/CLAUDE.md "$WORKTREE_PATH/CLAUDE.md"
    echo "[session_start] CLAUDE.md injetado em $WORKTREE_PATH"
elif [ -f "/repos/${ENV_SLUG}/CLAUDE.md" ]; then
    cp "/repos/${ENV_SLUG}/CLAUDE.md" "$WORKTREE_PATH/CLAUDE.md"
    echo "[session_start] CLAUDE.md copiado do repo principal para $WORKTREE_PATH"
fi

echo "[session_start] OK"
