# CappyCloud — Arquitetura

## Visão Geral

CappyCloud é uma plataforma de agentes IA: backend FastAPI + frontend React +
agentes openclaude rodando em containers Docker isolados (um por usuário) com
git worktrees por conversa.

## Arquitetura Hexagonal (Ports & Adapters)

```
┌─────────────────────────────────────────────────────────┐
│  Primary Adapters (driving)                             │
│  app/adapters/primary/http/  ← FastAPI routers (thin)  │
└────────────────┬────────────────────────────────────────┘
                 │ calls use cases
┌────────────────▼────────────────────────────────────────┐
│  Application Layer                                      │
│  app/application/use_cases/  ← ALL business logic here │
└────────────────┬────────────────────────────────────────┘
                 │ uses ports (ABCs)
┌────────────────▼────────────────────────────────────────┐
│  Ports (interfaces)                                     │
│  app/ports/  ← ABCs: UserRepository, AgentPort, etc.   │
└────────────────┬────────────────────────────────────────┘
                 │ implemented by
┌────────────────▼────────────────────────────────────────┐
│  Secondary Adapters (driven)                            │
│  app/adapters/secondary/  ← SQLAlchemy, Pipeline, etc. │
└─────────────────────────────────────────────────────────┘
```

## Directory Map

```
services/api/
  app/
    domain/          Pure Python entities + value objects (zero external imports)
    ports/           ABCs only — no implementations here
    application/     Use cases (orchestrate domain + ports)
    adapters/
      primary/http/  FastAPI routers + DI wiring (deps.py)
      secondary/     SQLAlchemy repos, PipelineAdapter, security services
    infrastructure/  config.py, database.py, security.py, orm_models.py
    schemas.py       Pydantic HTTP contracts (validators delegate to domain)
    main.py          FastAPI app + lifespan wiring only

tests/
  conftest.py        In-memory fakes + shared fixtures
  unit/              Test use cases + domain (no DB, no HTTP)
  adapter/           LSP contract tests (parametrized)
  integration/       Full HTTP tests via httpx + dependency_overrides

services/cappycloud_agent/
  cappycloud_pipeline.py   Pipeline principal (orquestra tudo)
  _environment_manager.py  Gerencia containers Docker por usuário
  _grpc_session.py         Sessão gRPC persistente por (user_id, chat_id)
  _session_store.py        Persistência de sessões (Redis + PostgreSQL)
  _grpc_bridge.py          Bridge HTTP → gRPC para uso externo

proto/
  openclaude.proto         Contrato gRPC do servidor openclaude

web/                       Frontend React (Vite + TypeScript)
```

## Arquitetura do Agente

O agente openclaude roda **dentro** de um container Docker e se comunica via gRPC.

```
Usuário envia mensagem
       ↓
  Pipeline (cappycloud_pipeline.py)
       ↓  garante container ativo e worktree git criado
  EnvironmentManager (_environment_manager.py)
       ↓  stream gRPC bidirecional persistente
  GrpcSession (_grpc_session.py) ──→  openclaude (gRPC :50051 no container)
                                              ↓
                                     LLM via OpenRouter
```

### Componentes do agente

| Classe | Arquivo | Responsabilidade |
|---|---|---|
| `Pipeline` | `cappycloud_pipeline.py` | Ponto de entrada; roteia mensagens para a sessão correta |
| `EnvironmentManager` | `_environment_manager.py` | Um container Docker por `user_id`; cria worktrees git por `chat_id` |
| `GrpcSession` | `_grpc_session.py` | Stream gRPC persistente; pausa em `ActionRequired`, retoma com `send_input()` |
| `SessionStore` | `_session_store.py` | Estado das sessões em Redis (TTL) + PostgreSQL (histórico) |

### Evento ActionRequired

Quando o openclaude precisa de confirmação humana, ele emite `ActionRequired` via gRPC.
O `GrpcSession` pausa o stream, expõe o `PendingAction` para o frontend e retoma
quando o usuário responde via `send_input()`.

## Integrações Externas

| Serviço | Uso |
|---|---|
| PostgreSQL | Usuários, conversas, sessões de agente |
| Redis | Cache de sessões com TTL |
| Docker | Containers de sandbox por usuário |
| OpenRouter | Gateway LLM (modelo configurável via `OPENROUTER_MODEL`) |
| openclaude gRPC | Servidor de agente dentro do container (porta 50051) |

## Comandos

```bash
cd services/api

# Instalar dependências de dev
pip install -r requirements.txt -e ".[dev]"

# Lint
ruff check .
ruff format --check .

# Type check
mypy app/

# Testes + cobertura
pytest

# Pre-commit (todos os arquivos)
pre-commit run --all-files
```
