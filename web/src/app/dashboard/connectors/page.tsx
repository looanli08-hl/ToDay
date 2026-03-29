"use client";

import { useState } from "react";
import { Card } from "@/components/ui/card";
import { connectors, categories, type Connector } from "@/lib/connectors";
import { Search, Blocks, Plus, Laptop } from "lucide-react";

// --- Device types & data ---

interface DeviceConnector {
  name: string;
  connected: boolean;
  action?: string;
}

interface Device {
  id: string;
  name: string;
  icon: string;
  type: "phone" | "computer";
  connectors: DeviceConnector[];
  lastSync: string | null;
}

const devices: Device[] = [
  {
    id: "iphone",
    name: "iPhone",
    icon: "📱",
    type: "phone",
    connectors: [
      { name: "Apple Health", connected: true },
      { name: "屏幕时间", connected: true },
      { name: "位置服务", connected: true },
      { name: "运动传感器", connected: true },
    ],
    lastSync: "2 分钟前",
  },
  {
    id: "computer",
    name: "当前电脑",
    icon: "💻",
    type: "computer",
    connectors: [
      { name: "浏览器扩展", connected: false, action: "安装" },
      { name: "桌面 Agent", connected: false, action: "下载" },
    ],
    lastSync: null,
  },
];

// --- Device Card component ---

function DeviceCard({ device }: { device: Device }) {
  return (
    <Card className="border border-border/40 bg-card rounded-xl p-6">
      <div className="flex items-center gap-3 mb-5">
        <span className="text-2xl">{device.icon}</span>
        <div>
          <h3 className="font-display text-base text-foreground">
            {device.name}
          </h3>
          <p className="text-xs text-muted-foreground">
            {device.connectors.filter((c) => c.connected).length}/
            {device.connectors.length} 已连接
          </p>
        </div>
      </div>

      <div className="space-y-3">
        {device.connectors.map((conn) => (
          <div key={conn.name} className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <div
                className={`h-2 w-2 rounded-full ${conn.connected ? "bg-emerald-500" : "bg-muted-foreground/30"}`}
              />
              <span className="text-sm text-foreground/80">
                {conn.name}
              </span>
            </div>
            {conn.connected ? (
              <span className="text-[11px] text-emerald-600 font-medium">
                已连接
              </span>
            ) : conn.action ? (
              <button className="rounded-lg bg-foreground px-3 py-1 text-[11px] font-medium text-background hover:opacity-90 transition-opacity">
                {conn.action}
              </button>
            ) : (
              <span className="text-[11px] text-muted-foreground">未连接</span>
            )}
          </div>
        ))}
      </div>

      <div className="mt-5 pt-4 border-t border-border/40">
        <div className="flex items-center gap-1.5">
          {device.lastSync ? (
            <>
              <div className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
              <span className="text-[11px] text-muted-foreground">
                最后同步：{device.lastSync}
              </span>
            </>
          ) : (
            <span className="text-[11px] text-muted-foreground">尚未同步</span>
          )}
        </div>
      </div>
    </Card>
  );
}

export default function ConnectorsPage() {
  const [activeCategory, setActiveCategory] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");

  const filtered = connectors.filter((c) => {
    const matchesCategory =
      activeCategory === "all" || c.category === activeCategory;
    const matchesSearch =
      searchQuery === "" ||
      c.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      c.description.includes(searchQuery);
    return matchesCategory && matchesSearch;
  });

  return (
    <div className="px-12 pt-12 pb-12">
      {/* Header */}
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-2">
          <Blocks className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
          <h1 className="font-display text-2xl tracking-tight text-foreground">连接器</h1>
        </div>
        <p className="text-sm text-muted-foreground">
          安装连接器，让 ToDay 自动从不同平台收集你的生活数据
        </p>
      </div>

      {/* Devices Section */}
      <div className="mb-10">
        <div className="flex items-center gap-2 mb-4">
          <Laptop className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
          <h2 className="font-display text-lg text-foreground">
            我的设备
          </h2>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          {devices.map((device) => (
            <DeviceCard key={device.id} device={device} />
          ))}
        </div>
      </div>

      {/* Marketplace Section */}
      <div>
        <div className="flex items-center gap-2 mb-4">
          <Blocks className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
          <h2 className="font-display text-lg text-foreground">
            连接器市场
          </h2>
        </div>

        {/* Search + Categories */}
        <div className="mb-6 space-y-4">
          <div className="relative max-w-md">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <input
              type="text"
              placeholder="搜索连接器..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full rounded-lg border border-border bg-background pl-10 pr-4 py-2.5 text-sm placeholder:text-muted-foreground/50 outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/40 transition-all"
            />
          </div>
          <div className="flex gap-2">
            {categories.map((cat) => (
              <button
                key={cat.id}
                onClick={() => setActiveCategory(cat.id)}
                className={`rounded-full px-4 py-1.5 text-sm font-medium transition-all ${
                  activeCategory === cat.id
                    ? "bg-foreground text-background"
                    : "bg-card text-muted-foreground hover:bg-accent border border-border/60"
                }`}
              >
                {cat.label}
              </button>
            ))}
          </div>
        </div>

        {/* Connector Grid */}
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {filtered.map((connector) => (
            <ConnectorCard key={connector.id} connector={connector} />
          ))}

          {/* "开发连接器" card */}
          <Card className="flex flex-col items-center justify-center border border-dashed border-border/60 bg-transparent rounded-xl p-6 hover:bg-card/50 transition-colors cursor-pointer group">
            <Plus className="h-4 w-4 text-muted-foreground/50 mb-3 group-hover:text-muted-foreground transition-colors" strokeWidth={1.5} />
            <p className="text-sm font-medium text-muted-foreground group-hover:text-foreground transition-colors">
              开发连接器
            </p>
            <p className="text-xs text-muted-foreground/60 mt-1">贡献到社区</p>
          </Card>
        </div>
      </div>
    </div>
  );
}

function ConnectorCard({ connector }: { connector: Connector }) {
  const statusConfig = {
    available: {
      label: "可用",
      className: "bg-emerald-50 text-emerald-700 border-emerald-200",
    },
    coming_soon: {
      label: "即将推出",
      className: "bg-amber-50 text-amber-700 border-amber-200",
    },
    community: {
      label: "社区",
      className: "bg-blue-50 text-blue-700 border-blue-200",
    },
  };

  const status = statusConfig[connector.status];

  return (
    <Card className="border border-border/40 bg-card rounded-xl p-6 hover:shadow-sm transition-all duration-200 group">
      <div className="flex items-start gap-4">
        <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-muted text-xl">
          {connector.icon}
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-1">
            <h3 className="text-sm font-semibold text-foreground/90">
              {connector.name}
            </h3>
            <span
              className={`inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-medium border ${status.className}`}
            >
              {status.label}
            </span>
          </div>
          <p className="text-xs text-muted-foreground leading-relaxed mb-3">
            {connector.description}
          </p>
          <div className="flex items-center justify-between">
            <div className="flex gap-1.5">
              {connector.dataTypes.slice(0, 3).map((type) => (
                <span
                  key={type}
                  className="rounded-lg bg-muted px-1.5 py-0.5 text-[11px] text-muted-foreground"
                >
                  {type}
                </span>
              ))}
            </div>
            <button
              className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-all ${
                connector.status === "available"
                  ? "bg-foreground text-background hover:opacity-90"
                  : "bg-muted text-muted-foreground cursor-not-allowed"
              }`}
              disabled={connector.status !== "available"}
            >
              {connector.status === "available" ? "安装" : "敬请期待"}
            </button>
          </div>
        </div>
      </div>
      <div className="mt-3 pt-3 border-t border-border/40">
        <p className="text-[11px] text-muted-foreground/60">
          by {connector.author}
        </p>
      </div>
    </Card>
  );
}
