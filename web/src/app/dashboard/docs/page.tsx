import { Card } from "@/components/ui/card";
import {
  BookOpen,
  Code,
  Terminal,
  ExternalLink,
  Zap,
  FileCode,
} from "lucide-react";

const sections = [
  {
    title: "快速开始",
    description: "5 分钟创建你的第一个连接器",
    icon: Zap,
    content: `1. 创建 CONNECTOR.md 描述文件
2. 实现数据采集逻辑
3. 调用 ToDay API 推送数据
4. 提交到社区市场`,
  },
  {
    title: "API 参考",
    description: "数据推送接口文档",
    icon: Code,
    content: `POST /api/data
{
  "source": "your-connector-id",
  "type": "steps",
  "value": 3500,
  "timestamp": "ISO 8601",
  "metadata": {}
}`,
  },
  {
    title: "CONNECTOR.md 规范",
    description: "连接器描述文件格式",
    icon: FileCode,
    content: `---
name: my-connector
description: 连接器描述
author: your-name
version: 1.0.0
dataTypes: [steps, sleep]
---

# My Connector
使用说明...`,
  },
];

export default function DocsPage() {
  return (
    <div className="p-10 max-w-4xl">
      {/* Header */}
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-2">
          <BookOpen className="h-6 w-6 text-primary" />
          <h1 className="text-2xl font-semibold tracking-tight">
            开发者文档
          </h1>
        </div>
        <p className="text-sm text-muted-foreground">
          学习如何为 ToDay 开发数据连接器，加入开源社区
        </p>
      </div>

      {/* Doc Sections */}
      <div className="space-y-6">
        {sections.map((section) => (
          <Card
            key={section.title}
            className="border-0 bg-card p-6 shadow-[0_1px_3px_rgba(0,0,0,0.04),0_1px_2px_rgba(0,0,0,0.02)]"
          >
            <div className="flex items-center gap-2.5 mb-3">
              <section.icon className="h-[18px] w-[18px] text-primary" />
              <h2 className="text-[15px] font-semibold">{section.title}</h2>
            </div>
            <p className="text-[13px] text-muted-foreground mb-4">
              {section.description}
            </p>
            <pre className="rounded-xl bg-[#1a1a2e] p-4 text-[12px] text-[#e0e0e0] font-mono leading-relaxed overflow-x-auto">
              {section.content}
            </pre>
          </Card>
        ))}
      </div>

      {/* Community Links */}
      <Card className="mt-8 border-0 bg-card p-6 shadow-[0_1px_3px_rgba(0,0,0,0.04),0_1px_2px_rgba(0,0,0,0.02)]">
        <h2 className="text-[15px] font-semibold mb-4">加入社区</h2>
        <div className="grid gap-3 sm:grid-cols-2">
          <a
            href="https://github.com/looanli08-hl/ToDay"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-3 rounded-xl border border-border/60 p-4 hover:bg-accent transition-colors group"
          >
            <div className="rounded-lg bg-muted p-2">
              <Code className="h-4 w-4 text-foreground/70" />
            </div>
            <div className="flex-1">
              <p className="text-sm font-medium">GitHub</p>
              <p className="text-[12px] text-muted-foreground">
                源码 &middot; Issues &middot; PR
              </p>
            </div>
            <ExternalLink className="h-3.5 w-3.5 text-muted-foreground group-hover:text-foreground transition-colors" />
          </a>
          <a
            href="#"
            className="flex items-center gap-3 rounded-xl border border-border/60 p-4 hover:bg-accent transition-colors group"
          >
            <div className="rounded-lg bg-muted p-2">
              <Terminal className="h-4 w-4 text-foreground/70" />
            </div>
            <div className="flex-1">
              <p className="text-sm font-medium">Discord</p>
              <p className="text-[12px] text-muted-foreground">
                讨论 &middot; 求助 &middot; 分享
              </p>
            </div>
            <ExternalLink className="h-3.5 w-3.5 text-muted-foreground group-hover:text-foreground transition-colors" />
          </a>
        </div>
      </Card>
    </div>
  );
}
