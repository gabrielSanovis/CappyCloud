import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  AppShell,
  Badge,
  Burger,
  Button,
  Divider,
  Group,
  ScrollArea,
  Select,
  Stack,
  Text,
  Textarea,
  Title,
  UnstyledButton,
} from '@mantine/core'
import { useDisclosure } from '@mantine/hooks'
import {
  createConversation,
  fetchConversations,
  fetchMessages,
  fetchRepoEnvironments,
  getToken,
  setToken,
  streamAssistantReply,
  type ActionRequiredEvent,
  type ChatMessage,
  type Conversation,
  type RepoEnv,
} from '../api'
import { ActionRequiredCard } from '../components/ActionRequiredCard'
import { ThinkingIndicator } from '../components/ThinkingIndicator'
import { ToolCallCard, type ToolCallState } from '../components/ToolCallCard'
import styles from '../components/chat.module.css'

/**
 * UI principal: lista de conversas e chat com streaming do agente.
 * Suporta tool calls animados, HITL (confirmação/opções), e animações de digitação.
 */
export function ChatPage() {
  const token = getToken()!
  const [mobileOpened, { toggle: toggleMobile }] = useDisclosure()

  const [conversations, setConversations] = useState<Conversation[]>([])
  const [activeId, setActiveId] = useState<string | null>(null)
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [input, setInput] = useState('')
  const [streaming, setStreaming] = useState(false)
  const [loading, setLoading] = useState(true)

  // Environments
  const [envs, setEnvs] = useState<RepoEnv[]>([])
  const [selectedEnvId, setSelectedEnvId] = useState<string | null>(null)

  // Streaming state
  const [pendingText, setPendingText] = useState('')
  const [pendingTools, setPendingTools] = useState<ToolCallState[]>([])
  const [pendingAction, setPendingAction] = useState<ActionRequiredEvent | null>(null)

  const scrollRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' })
    }
  }, [messages, pendingText, pendingTools, pendingAction, streaming])

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      try {
        const [list, envList] = await Promise.all([
          fetchConversations(token),
          fetchRepoEnvironments(token),
        ])
        if (cancelled) return
        setConversations(list)
        setEnvs(envList)
        if (list.length > 0) {
          setActiveId((prev) => prev ?? list[0].id)
        }
      } finally {
        if (!cancelled) setLoading(false)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [token])

  useEffect(() => {
    if (!activeId) return
    let cancelled = false
    ;(async () => {
      const msgs = await fetchMessages(token, activeId)
      if (!cancelled) setMessages(msgs)
    })()
    return () => {
      cancelled = true
    }
  }, [activeId, token])

  async function handleNewChat() {
    const c = await createConversation(token, selectedEnvId)
    setConversations((prev) => [c, ...prev])
    setActiveId(c.id)
    setMessages([])
  }

  async function handleSend(textOverride?: string) {
    const text = (textOverride ?? input).trim()
    if (!text || !activeId || streaming) return

    if (!textOverride) setInput('')
    setStreaming(true)
    setPendingText('')
    setPendingTools([])
    setPendingAction(null)

    const userMsg: ChatMessage = {
      id: crypto.randomUUID(),
      role: 'user',
      content: text,
      created_at: new Date().toISOString(),
    }
    setMessages((m) => [...m, userMsg])

    try {
      await streamAssistantReply(token, activeId, text, {
        onText(accumulated) {
          setPendingText(accumulated)
        },
        onToolStart(tool) {
          setPendingTools((prev) => [
            ...prev,
            { id: tool.id, name: tool.name, input: tool.input, done: false },
          ])
        },
        onToolResult(result) {
          setPendingTools((prev) =>
            prev.map((t) =>
              t.id === result.id
                ? { ...t, output: result.output, isError: result.is_error, done: true }
                : t
            )
          )
        },
        onActionRequired(action) {
          setPendingAction(action)
        },
        onError(message) {
          setMessages((m) => [
            ...m,
            {
              id: crypto.randomUUID(),
              role: 'assistant',
              content: `**Erro:** ${message}`,
              created_at: new Date().toISOString(),
            },
          ])
        },
      })

      setPendingText('')
      setPendingTools([])
      const msgs = await fetchMessages(token, activeId)
      setMessages(msgs)
    } catch (e) {
      setMessages((m) => [
        ...m,
        {
          id: crypto.randomUUID(),
          role: 'assistant',
          content: `**Erro:** ${e instanceof Error ? e.message : String(e)}`,
          created_at: new Date().toISOString(),
        },
      ])
    } finally {
      setStreaming(false)
    }
  }

  function handleActionReply(reply: string) {
    handleSend(reply)
  }

  function logout() {
    setToken(null)
    window.location.reload()
  }

  const activeConv = conversations.find((c) => c.id === activeId)
  const activeTitle = activeConv?.title ?? 'Conversa'
  const activeEnvSlug = activeConv?.env_slug ?? null
  const showThinking = streaming && !pendingText && pendingTools.every((t) => t.done) && !pendingAction

  const envSelectData = [
    { value: '', label: 'Sem ambiente (sandbox vazio)' },
    ...envs.map((e) => ({ value: e.id, label: `${e.name} (${e.slug})` })),
  ]

  if (loading) {
    return (
      <Group justify="center" p="xl">
        <ThinkingIndicator />
      </Group>
    )
  }

  return (
    <AppShell
      header={{ height: 56 }}
      navbar={{
        width: 280,
        breakpoint: 'sm',
        collapsed: { mobile: !mobileOpened },
      }}
      padding="md"
    >
      <AppShell.Header>
        <Group h="100%" px="md" justify="space-between">
          <Group>
            <Burger opened={mobileOpened} onClick={toggleMobile} hiddenFrom="sm" size="sm" />
            <Title order={4}>CappyCloud</Title>
          </Group>
          <Group>
            <Button component={Link} to="/environments" variant="subtle" size="xs">
              Ambientes
            </Button>
            <Button variant="subtle" onClick={logout}>
              Sair
            </Button>
          </Group>
        </Group>
      </AppShell.Header>

      <AppShell.Navbar p="md">
        <Stack gap="xs" mb="sm">
          <Select
            size="xs"
            label="Ambiente para nova conversa"
            placeholder="Sem ambiente"
            data={envSelectData}
            value={selectedEnvId ?? ''}
            onChange={(v) => setSelectedEnvId(v || null)}
            clearable={false}
          />
          <Button fullWidth size="sm" onClick={handleNewChat}>
            Nova conversa
          </Button>
        </Stack>

        <Divider mb="xs" />

        <ScrollArea h="calc(100vh - 200px)">
          <Stack gap={4}>
            {conversations.map((c) => (
              <UnstyledButton
                key={c.id}
                onClick={() => setActiveId(c.id)}
                p="xs"
                style={{
                  borderRadius: 8,
                  background: c.id === activeId ? 'var(--mantine-color-dark-5)' : undefined,
                }}
              >
                <Text size="sm" lineClamp={1}>
                  {c.title}
                </Text>
                {c.env_slug && (
                  <Badge size="xs" variant="dot" color="teal" mt={2}>
                    {c.env_slug}
                  </Badge>
                )}
              </UnstyledButton>
            ))}
          </Stack>
        </ScrollArea>
      </AppShell.Navbar>

      <AppShell.Main>
        <Group mb="md" gap="xs" align="center">
          <Title order={5}>{activeTitle}</Title>
          {activeEnvSlug && (
            <Badge size="sm" variant="light" color="teal">
              {activeEnvSlug}
            </Badge>
          )}
        </Group>

        {!activeId ? (
          <Text c="dimmed">Crie uma conversa para começar.</Text>
        ) : (
          <>
            <ScrollArea
              h="calc(100vh - 220px)"
              mb="md"
              type="auto"
              viewportRef={scrollRef}
            >
              <Stack gap="md">
                {messages.map((m) => (
                  <PaperMessage key={m.id} role={m.role} content={m.content} />
                ))}

                {streaming && (
                  <Stack gap="xs">
                    {pendingTools.map((tool) => (
                      <ToolCallCard key={tool.id} tool={tool} />
                    ))}
                    {showThinking && <ThinkingIndicator />}
                    {pendingText && (
                      <PaperMessage role="assistant" content={pendingText} />
                    )}
                  </Stack>
                )}

                {pendingAction && (
                  <ActionRequiredCard
                    action={pendingAction}
                    onReply={handleActionReply}
                  />
                )}
              </Stack>
            </ScrollArea>

            <Textarea
              placeholder="Mensagem ao agente… (Enter para enviar, Shift+Enter para nova linha)"
              minRows={3}
              value={input}
              onChange={(e) => setInput(e.currentTarget.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey && !streaming) {
                  e.preventDefault()
                  handleSend()
                }
              }}
              disabled={streaming && !pendingAction}
            />
            <Button
              mt="sm"
              onClick={() => handleSend()}
              loading={streaming && !pendingAction}
              disabled={(!input.trim() && !pendingAction) || (streaming && !pendingAction)}
            >
              Enviar
            </Button>
          </>
        )}
      </AppShell.Main>
    </AppShell>
  )
}

function PaperMessage({ role, content }: { role: string; content: string }) {
  const isUser = role === 'user'
  return (
    <div
      className={styles.message}
      style={{
        alignSelf: isUser ? 'flex-end' : 'flex-start',
        maxWidth: '90%',
        padding: '12px 16px',
        borderRadius: 12,
        background: isUser ? 'var(--mantine-color-teal-9)' : 'var(--mantine-color-dark-6)',
        whiteSpace: 'pre-wrap',
      }}
    >
      <Text size="xs" c="dimmed" mb={4}>
        {isUser ? 'Tu' : 'Agente'}
      </Text>
      <Text size="sm">{content}</Text>
    </div>
  )
}

