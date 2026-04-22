-- ──────────────────────────────────────────────────────────────
-- Init 01 — Sandboxes registry
--
-- Roda uma única vez no init do volume PostgreSQL (após 00-extensions.sql).
-- Apenas cria a tabela `sandboxes` e insere o sandbox padrão.
--
-- IMPORTANTE: ALTER TABLE em `conversations` e `agent_tasks` foram
-- REMOVIDOS daqui — essas colunas são gerenciadas pelas migrations
-- Alembic (20260419_191734 e posteriores). Manter os ALTERs aqui
-- causaria erro ao inicializar um volume novo, pois o Alembic ainda
-- não rodou e a tabela `conversations` não existe.
-- ──────────────────────────────────────────────────────────────

-- ── Sandboxes ─────────────────────────────────────────────────
-- Cada linha representa um container sandbox rodando openclaude gRPC.
-- status: active | draining (sem novas sessões) | offline
CREATE TABLE IF NOT EXISTS sandboxes (
    id           UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    name         VARCHAR(128) UNIQUE NOT NULL,
    host         VARCHAR(256) NOT NULL,
    grpc_port    INTEGER      NOT NULL DEFAULT 50051,
    session_port INTEGER      NOT NULL DEFAULT 8080,
    status       VARCHAR(32)  NOT NULL DEFAULT 'active',
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Sandbox padrão configurado pelo docker-compose
INSERT INTO sandboxes (name, host, grpc_port, session_port, status)
VALUES ('cappycloud-sandbox', 'cappycloud-sandbox', 50051, 8080, 'active')
ON CONFLICT (name) DO NOTHING;
