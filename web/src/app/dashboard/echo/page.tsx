"use client";

import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type KeyboardEvent,
  type FormEvent,
} from "react";
import { cn } from "@/lib/utils";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import {
  ClipboardList,
  Moon,
  Coffee,
  Calendar,
  Lightbulb,
  Sparkles,
  Plus,
  Search,
  Send,
  MessageSquare,
  Trash2,
  X,
} from "lucide-react";
import { EchoSymbol, EchoAvatar } from "@/components/echo-symbol";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface Message {
  id: string;
  role: "user" | "assistant";
  content: string;
}

interface Conversation {
  id: string;
  title: string;
  messages: Message[];
  createdAt: Date;
  updatedAt: Date;
}

// ---------------------------------------------------------------------------
// Suggested prompts shown on the empty state
// ---------------------------------------------------------------------------

const SUGGESTED_PROMPTS = [
  { label: "帮我回顾今天做了什么", icon: ClipboardList },
  { label: "分析一下我最近的作息", icon: Moon },
  { label: "我有点累了，聊聊天吧", icon: Coffee },
  { label: "帮我规划明天的安排", icon: Calendar },
  { label: "记录一个灵感想法", icon: Lightbulb },
  { label: "给我一些正能量", icon: Sparkles },
];

// ---------------------------------------------------------------------------
// Stream parser — reads SSE from DeepSeek via our API route
// ---------------------------------------------------------------------------

async function streamResponse(
  messages: { role: string; content: string }[],
  onToken: (token: string) => void,
  onDone: () => void,
  onError: (err: string) => void
) {
  try {
    const res = await fetch("/api/echo/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ messages }),
    });

    if (!res.ok) {
      onError("Echo 暂时无法回应，请稍后再试");
      onDone();
      return;
    }

    const reader = res.body?.getReader();
    if (!reader) {
      onError("无法读取响应流");
      onDone();
      return;
    }

    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      // Keep the last potentially incomplete line in the buffer
      buffer = lines.pop() || "";

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed.startsWith("data: ")) continue;

        const data = trimmed.slice(6);
        if (data === "[DONE]") {
          onDone();
          return;
        }

        try {
          const parsed = JSON.parse(data);
          const token = parsed.choices?.[0]?.delta?.content;
          if (token) onToken(token);
        } catch {
          // Skip malformed JSON chunks
        }
      }
    }

    onDone();
  } catch {
    onError("网络连接异常，请检查网络后重试");
    onDone();
  }
}

// ---------------------------------------------------------------------------
// Utility: generate a short title from the first user message
// ---------------------------------------------------------------------------

function generateTitle(content: string): string {
  const cleaned = content.replace(/\n/g, " ").trim();
  if (cleaned.length <= 24) return cleaned;
  return cleaned.slice(0, 24) + "…";
}

function uid(): string {
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

function TypingIndicator() {
  return (
    <div className="flex items-center gap-1.5 px-1 py-2">
      <div className="h-1.5 w-1.5 rounded-full bg-primary/50 animate-bounce [animation-delay:0ms]" />
      <div className="h-1.5 w-1.5 rounded-full bg-primary/50 animate-bounce [animation-delay:150ms]" />
      <div className="h-1.5 w-1.5 rounded-full bg-primary/50 animate-bounce [animation-delay:300ms]" />
    </div>
  );
}

// EchoAvatar is imported from @/components/echo-symbol

function EchoMessageContent({ content }: { content: string }) {
  return (
    <div className="prose prose-sm max-w-none text-foreground/85 leading-relaxed [&>*:first-child]:mt-0 [&>*:last-child]:mb-0 [&_p]:my-1.5 [&_ul]:my-1.5 [&_ol]:my-1.5 [&_li]:my-0.5 [&_code]:bg-muted [&_code]:px-1.5 [&_code]:py-0.5 [&_code]:rounded-lg [&_code]:text-sm [&_code]:font-mono [&_pre]:bg-foreground [&_pre]:text-background [&_pre]:rounded-xl [&_pre]:p-4 [&_pre]:my-3 [&_pre_code]:bg-transparent [&_pre_code]:p-0 [&_blockquote]:border-l-primary/40 [&_blockquote]:text-muted-foreground [&_a]:text-primary [&_a]:no-underline hover:[&_a]:underline [&_h1]:text-base [&_h2]:text-base [&_h3]:text-sm [&_strong]:text-foreground/90">
      <ReactMarkdown remarkPlugins={[remarkGfm]}>{content}</ReactMarkdown>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Main page component
// ---------------------------------------------------------------------------

export default function EchoPage() {
  // Conversation state
  const [conversations, setConversations] = useState<Conversation[]>(() => {
    if (typeof window === "undefined") return [];
    try {
      const saved = localStorage.getItem("echo-conversations");
      if (saved) {
        const parsed = JSON.parse(saved);
        return parsed.map((c: Conversation) => ({
          ...c,
          createdAt: new Date(c.createdAt),
          updatedAt: new Date(c.updatedAt),
        }));
      }
    } catch {}
    return [];
  });
  const [activeId, setActiveId] = useState<string | null>(() => {
    if (typeof window === "undefined") return null;
    return localStorage.getItem("echo-active-id") || null;
  });
  const [searchQuery, setSearchQuery] = useState("");

  // Chat state
  const [inputValue, setInputValue] = useState("");
  const [isStreaming, setIsStreaming] = useState(false);
  const [streamingContent, setStreamingContent] = useState("");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Sidebar state
  const [sidebarOpen, setSidebarOpen] = useState(true);

  // Persist conversations to localStorage
  useEffect(() => {
    localStorage.setItem("echo-conversations", JSON.stringify(conversations));
  }, [conversations]);

  useEffect(() => {
    if (activeId) {
      localStorage.setItem("echo-active-id", activeId);
    } else {
      localStorage.removeItem("echo-active-id");
    }
  }, [activeId]);

  // Refs
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const messagesContainerRef = useRef<HTMLDivElement>(null);

  // Derived
  const activeConversation = conversations.find((c) => c.id === activeId);
  const messages = activeConversation?.messages ?? [];

  const filteredConversations = searchQuery
    ? conversations.filter((c) =>
        c.title.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : conversations;

  // -------------------------------------------------------------------------
  // Scroll to bottom
  // -------------------------------------------------------------------------

  const scrollToBottom = useCallback(() => {
    requestAnimationFrame(() => {
      messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    });
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages.length, streamingContent, scrollToBottom]);

  // -------------------------------------------------------------------------
  // Auto-resize textarea
  // -------------------------------------------------------------------------

  useEffect(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = Math.min(el.scrollHeight, 160) + "px";
  }, [inputValue]);

  // Focus textarea on mount and conversation switch
  useEffect(() => {
    if (!isStreaming) {
      textareaRef.current?.focus();
    }
  }, [activeId, isStreaming]);

  // -------------------------------------------------------------------------
  // Create new conversation
  // -------------------------------------------------------------------------

  const createConversation = useCallback(
    (initialMessage?: string): string => {
      const newConv: Conversation = {
        id: uid(),
        title: initialMessage ? generateTitle(initialMessage) : "新对话",
        messages: [],
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      setConversations((prev) => [newConv, ...prev]);
      setActiveId(newConv.id);
      setErrorMessage(null);
      return newConv.id;
    },
    []
  );

  // -------------------------------------------------------------------------
  // Delete conversation
  // -------------------------------------------------------------------------

  const deleteConversation = useCallback(
    (id: string) => {
      setConversations((prev) => prev.filter((c) => c.id !== id));
      if (activeId === id) {
        setActiveId(null);
      }
    },
    [activeId]
  );

  // -------------------------------------------------------------------------
  // Send message
  // -------------------------------------------------------------------------

  const sendMessage = useCallback(
    async (content: string) => {
      if (!content.trim() || isStreaming) return;

      const trimmed = content.trim();
      setInputValue("");
      setErrorMessage(null);

      // Determine which conversation to use
      let convId = activeId;
      if (!convId) {
        convId = createConversation(trimmed);
      }

      // Add user message
      const userMsg: Message = { id: uid(), role: "user", content: trimmed };

      setConversations((prev) =>
        prev.map((c) => {
          if (c.id !== convId) return c;
          const updated = {
            ...c,
            messages: [...c.messages, userMsg],
            updatedAt: new Date(),
          };
          // Update title if it's the first message
          if (c.messages.length === 0) {
            updated.title = generateTitle(trimmed);
          }
          return updated;
        })
      );

      // Start streaming
      setIsStreaming(true);
      setStreamingContent("");

      // Build message history for the API
      const currentConv = conversations.find((c) => c.id === convId);
      const history = [
        ...(currentConv?.messages ?? []).map((m) => ({
          role: m.role,
          content: m.content,
        })),
        { role: "user" as const, content: trimmed },
      ];

      let accumulated = "";

      await streamResponse(
        history,
        (token) => {
          accumulated += token;
          setStreamingContent(accumulated);
        },
        () => {
          // Add assistant message to conversation
          const assistantMsg: Message = {
            id: uid(),
            role: "assistant",
            content: accumulated,
          };
          setConversations((prev) =>
            prev.map((c) => {
              if (c.id !== convId) return c;
              return {
                ...c,
                messages: [...c.messages, assistantMsg],
                updatedAt: new Date(),
              };
            })
          );
          setStreamingContent("");
          setIsStreaming(false);
        },
        (err) => {
          setErrorMessage(err);
          // Still add partial content if any
          if (accumulated) {
            const assistantMsg: Message = {
              id: uid(),
              role: "assistant",
              content: accumulated,
            };
            setConversations((prev) =>
              prev.map((c) => {
                if (c.id !== convId) return c;
                return {
                  ...c,
                  messages: [...c.messages, assistantMsg],
                  updatedAt: new Date(),
                };
              })
            );
          }
          setStreamingContent("");
          setIsStreaming(false);
        }
      );
    },
    [activeId, conversations, createConversation, isStreaming]
  );

  // -------------------------------------------------------------------------
  // Keyboard handling
  // -------------------------------------------------------------------------

  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      sendMessage(inputValue);
    }
  };

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    sendMessage(inputValue);
  };

  // -------------------------------------------------------------------------
  // Time formatting
  // -------------------------------------------------------------------------

  function formatTime(date: Date): string {
    const now = new Date();
    const d = new Date(date);
    const diffMs = now.getTime() - d.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return "刚刚";
    if (diffMins < 60) return `${diffMins}分钟前`;
    if (diffHours < 24) return `${diffHours}小时前`;
    if (diffDays < 7) return `${diffDays}天前`;
    return d.toLocaleDateString("zh-CN", { month: "short", day: "numeric" });
  }

  // -------------------------------------------------------------------------
  // Greeting based on time of day
  // -------------------------------------------------------------------------

  function getGreeting(): string {
    const hour = new Date().getHours();
    if (hour < 6) return "夜深了，还没休息吗？";
    if (hour < 9) return "早上好，新的一天开始了";
    if (hour < 12) return "上午好，今天有什么计划吗？";
    if (hour < 14) return "中午好，别忘了休息一下";
    if (hour < 18) return "下午好，今天过得怎么样？";
    if (hour < 22) return "晚上好，来聊聊今天的感受吧";
    return "夜深了，早点休息哦";
  }

  // =========================================================================
  // Render
  // =========================================================================

  return (
    <div className="flex h-full overflow-hidden">
      {/* ----------------------------------------------------------------- */}
      {/* Sidebar                                                           */}
      {/* ----------------------------------------------------------------- */}
      <aside
        className={cn(
          "flex flex-col border-r border-border/50 bg-[var(--sidebar)] transition-all duration-300 ease-in-out",
          sidebarOpen ? "w-[280px] min-w-[280px]" : "w-0 min-w-0 overflow-hidden"
        )}
      >
        {/* Sidebar header */}
        <div className="flex items-center justify-between px-4 pt-5 pb-3">
          <h2 className="text-sm font-semibold text-foreground/80">对话</h2>
          <button
            onClick={() => {
              createConversation();
              setInputValue("");
            }}
            className="flex h-7 w-7 items-center justify-center rounded-lg text-muted-foreground hover:bg-accent hover:text-foreground transition-colors"
            title="新建对话"
          >
            <Plus className="h-4 w-4" />
          </button>
        </div>

        {/* Search */}
        <div className="px-3 pb-2">
          <div className="relative">
            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground/60" />
            <input
              type="text"
              placeholder="搜索对话…"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full rounded-lg bg-white/60 border border-border/40 py-1.5 pl-8 pr-3 text-sm text-foreground placeholder:text-muted-foreground/50 outline-none focus:border-primary/30 focus:bg-white transition-colors"
            />
          </div>
        </div>

        {/* Conversation list */}
        <div className="flex-1 overflow-y-auto px-2 pb-4 space-y-0.5">
          {filteredConversations.length === 0 && (
            <div className="px-3 py-8 text-center">
              <MessageSquare className="h-8 w-8 mx-auto text-muted-foreground/30 mb-2" />
              <p className="text-xs text-muted-foreground/60">
                {searchQuery ? "没有找到匹配的对话" : "开始你的第一次对话吧"}
              </p>
            </div>
          )}
          {filteredConversations.map((conv) => (
            <div
              key={conv.id}
              className={cn(
                "group relative flex items-center gap-2.5 rounded-lg px-3 py-2.5 cursor-pointer transition-all duration-150",
                conv.id === activeId
                  ? "bg-white text-foreground"
                  : "text-foreground/70 hover:bg-white/50"
              )}
              onClick={() => {
                setActiveId(conv.id);
                setErrorMessage(null);
              }}
            >
              <MessageSquare className="h-4 w-4 flex-shrink-0 text-muted-foreground/50" />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate">{conv.title}</p>
                <p className="text-[11px] text-muted-foreground/60 mt-0.5">
                  {formatTime(conv.updatedAt)}
                  {conv.messages.length > 0 &&
                    ` · ${conv.messages.length} 条消息`}
                </p>
              </div>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  deleteConversation(conv.id);
                }}
                className="opacity-0 group-hover:opacity-100 flex h-6 w-6 items-center justify-center rounded-lg text-muted-foreground/50 hover:text-destructive hover:bg-destructive/10 transition-all"
                title="删除对话"
              >
                <Trash2 className="h-3 w-3" />
              </button>
            </div>
          ))}
        </div>
      </aside>

      {/* ----------------------------------------------------------------- */}
      {/* Main chat area                                                     */}
      {/* ----------------------------------------------------------------- */}
      <div className="flex flex-1 flex-col min-w-0">
        {/* Chat header */}
        <div className="flex items-center gap-3 border-b border-border/40 px-5 py-3 bg-background/50 backdrop-blur-sm">
          <button
            onClick={() => setSidebarOpen(!sidebarOpen)}
            className="flex h-7 w-7 items-center justify-center rounded-lg text-muted-foreground hover:bg-accent hover:text-foreground transition-colors lg:hidden"
          >
            {sidebarOpen ? (
              <X className="h-4 w-4" />
            ) : (
              <MessageSquare className="h-4 w-4" />
            )}
          </button>
          <div className="flex items-center gap-2">
            <EchoAvatar size="sm" />
            <div>
              <h1 className="font-display text-base text-foreground">
                Echo
              </h1>
              <p className="text-[11px] text-muted-foreground/60">
                {isStreaming ? "正在思考…" : "你的 AI 生活伙伴"}
              </p>
            </div>
          </div>
        </div>

        {/* Messages area */}
        <div
          ref={messagesContainerRef}
          className="flex-1 overflow-y-auto"
        >
          {messages.length === 0 && !streamingContent ? (
            /* ---- Empty state ---- */
            <div className="flex h-full flex-col items-center justify-center px-6 pb-8">
              <div className="mb-8 text-center">
                <div className="mb-5 flex justify-center">
                  <div className="relative">
                    <EchoAvatar size="lg" />
                    <div className="absolute -bottom-0.5 -right-0.5 h-4 w-4 rounded-full bg-emerald-500 border-[2.5px] border-background" />
                  </div>
                </div>
                <h2 className="font-display text-2xl font-normal text-foreground mb-2">
                  Echo 在这里
                </h2>
                <p className="text-base text-muted-foreground max-w-sm">
                  {getGreeting()}
                </p>
              </div>

              {/* Suggested prompts */}
              <div className="grid grid-cols-2 gap-2.5 max-w-lg w-full">
                {SUGGESTED_PROMPTS.map((prompt) => (
                  <button
                    key={prompt.label}
                    onClick={() => sendMessage(prompt.label)}
                    disabled={isStreaming}
                    className="group flex items-center gap-3 rounded-xl border border-border/50 bg-card px-4 py-3 text-left transition-all duration-200 hover:border-border active:scale-[0.99] disabled:opacity-50"
                  >
                    <prompt.icon className="h-4 w-4 text-muted-foreground/40" strokeWidth={1.5} />
                    <span className="text-sm text-muted-foreground group-hover:text-foreground transition-colors">
                      {prompt.label}
                    </span>
                  </button>
                ))}
              </div>
            </div>
          ) : (
            /* ---- Message list ---- */
            <div className="mx-auto max-w-3xl px-4 py-6 space-y-5">
              {messages.map((msg) => (
                <div
                  key={msg.id}
                  className={cn(
                    "flex gap-3",
                    msg.role === "user" ? "justify-end" : "justify-start"
                  )}
                >
                  {msg.role === "assistant" && (
                    <EchoAvatar size="sm" />
                  )}
                  <div
                    className={cn(
                      "max-w-[85%]",
                      msg.role === "user"
                        ? "bg-foreground text-background rounded-xl rounded-br-lg px-4 py-3"
                        : "pt-0.5"
                    )}
                  >
                    {msg.role === "user" ? (
                      <p className="text-sm leading-relaxed whitespace-pre-wrap">
                        {msg.content}
                      </p>
                    ) : (
                      <EchoMessageContent content={msg.content} />
                    )}
                  </div>
                </div>
              ))}

              {/* Streaming response */}
              {isStreaming && (
                <div className="flex gap-3 justify-start">
                  <EchoAvatar size="sm" />
                  <div className="pt-0.5 max-w-[85%]">
                    {streamingContent ? (
                      <EchoMessageContent content={streamingContent} />
                    ) : (
                      <TypingIndicator />
                    )}
                  </div>
                </div>
              )}

              {/* Error message */}
              {errorMessage && (
                <div className="flex justify-center">
                  <div className="inline-flex items-center gap-2 rounded-lg bg-destructive/10 px-4 py-2 text-sm text-destructive">
                    <span>⚠</span>
                    {errorMessage}
                  </div>
                </div>
              )}

              <div ref={messagesEndRef} />
            </div>
          )}
        </div>

        {/* ---- Input area ---- */}
        <div className="border-t border-border/40 bg-background/80 backdrop-blur-sm px-4 py-3">
          <form
            onSubmit={handleSubmit}
            className="mx-auto max-w-3xl"
          >
            <div className="relative flex items-end gap-2 rounded-xl border border-border/60 bg-white px-4 py-2.5 transition-all duration-200 focus-within:border-primary/40">
              <textarea
                ref={textareaRef}
                value={inputValue}
                onChange={(e) => setInputValue(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder="跟 Echo 说点什么…"
                disabled={isStreaming}
                rows={1}
                className="flex-1 resize-none bg-transparent text-sm text-foreground leading-relaxed placeholder:text-muted-foreground/50 outline-none disabled:opacity-50 max-h-[160px]"
              />
              <button
                type="submit"
                disabled={!inputValue.trim() || isStreaming}
                className={cn(
                  "flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-lg transition-all duration-200",
                  inputValue.trim() && !isStreaming
                    ? "bg-primary text-primary-foreground hover:opacity-90 active:scale-95"
                    : "bg-muted text-muted-foreground/40"
                )}
              >
                <Send className="h-4 w-4" />
              </button>
            </div>
            <div className="flex items-center justify-between mt-1.5 px-1">
              <p className="text-[11px] text-muted-foreground/50">
                Shift+Enter 换行，Enter 发送
              </p>
              <p className="text-[11px] text-muted-foreground/50">
                Echo
              </p>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
