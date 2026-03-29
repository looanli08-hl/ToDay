"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { createClient } from "@/lib/supabase/client";
import {
  Compass,
  CalendarDays,
  LineChart,
  Layers,
  Palette,
  Bot,
  Blocks,
  FileCode2,
  Plus,
  Search,
  Settings,
} from "lucide-react";

const mainNav = [
  { href: "/dashboard", label: "概览", icon: Compass },
  { href: "/dashboard/timeline", label: "时间线", icon: CalendarDays },
  { href: "/dashboard/analytics", label: "数据分析", icon: LineChart },
  { href: "/dashboard/screen-time", label: "屏幕时间", icon: Layers },
  { href: "/dashboard/mood", label: "心情记录", icon: Palette },
  { href: "/dashboard/echo", label: "Echo AI", icon: Bot },
  { href: "/dashboard/connectors", label: "连接器", icon: Blocks },
  { href: "/dashboard/docs", label: "开发文档", icon: FileCode2 },
];

const bottomNav = [
  { href: "/dashboard/settings", label: "设置", icon: Settings },
];

export function Sidebar() {
  const pathname = usePathname();
  const [userName, setUserName] = useState("...");

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (user) {
        setUserName(
          user.user_metadata?.display_name ||
            user.email?.split("@")[0] ||
            "用户"
        );
      }
    });
  }, []);

  return (
    <aside className="flex h-screen w-[260px] flex-col bg-[var(--sidebar)]">
      {/* Logo + Actions */}
      <div className="flex items-center justify-between px-4 pt-4 pb-2">
        <div className="flex items-center gap-2.5">
          <div className="flex h-8 w-8 items-center justify-center rounded-xl bg-gradient-to-br from-[#D4864A] to-[#E8A06A] shadow-sm shadow-[#D4864A]/20">
            <span className="text-[13px] font-bold text-white tracking-tight">T</span>
          </div>
          <span className="text-[15px] font-semibold tracking-tight text-foreground/90">ToDay</span>
        </div>
      </div>

      {/* New + Search */}
      <div className="px-3 py-2 space-y-1">
        <button className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-sm text-muted-foreground hover:bg-accent transition-colors">
          <Plus className="h-4 w-4" />
          <span>新建记录</span>
        </button>
        <button className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-sm text-muted-foreground hover:bg-accent transition-colors">
          <Search className="h-4 w-4" />
          <span>搜索</span>
        </button>
      </div>

      {/* Divider */}
      <div className="mx-4 my-1 h-px bg-border/60" />

      {/* Main Navigation */}
      <nav className="flex-1 space-y-0.5 px-3 py-2">
        {mainNav.map((item) => {
          const isActive =
            pathname === item.href ||
            (item.href !== "/dashboard" && pathname.startsWith(item.href));
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-2.5 rounded-lg px-3 py-2 text-[13px] font-medium transition-all duration-150",
                isActive
                  ? "bg-accent text-foreground shadow-[0_1px_2px_rgba(0,0,0,0.04)]"
                  : "text-muted-foreground hover:bg-accent/60 hover:text-foreground/80"
              )}
            >
              <item.icon className="h-4 w-4" strokeWidth={1.8} />
              {item.label}
            </Link>
          );
        })}
      </nav>

      {/* Bottom */}
      <div className="px-3 pb-2">
        {bottomNav.map((item) => {
          const isActive = pathname.startsWith(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-2.5 rounded-lg px-3 py-2 text-[13px] font-medium transition-colors",
                isActive
                  ? "bg-accent text-foreground"
                  : "text-muted-foreground hover:bg-accent/60 hover:text-foreground/80"
              )}
            >
              <item.icon className="h-4 w-4" strokeWidth={1.8} />
              {item.label}
            </Link>
          );
        })}
      </div>

      {/* User Profile */}
      <div className="border-t border-border/50 px-3 py-3">
        <div className="flex items-center gap-2.5 rounded-lg px-2 py-1.5 hover:bg-accent/60 transition-colors cursor-pointer">
          <div className="flex h-7 w-7 items-center justify-center rounded-full bg-gradient-to-br from-[#e8734a]/20 to-[#f59e6c]/20 text-[#e8734a]">
            <span className="text-xs font-semibold">
              {userName.charAt(0).toUpperCase()}
            </span>
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-[13px] font-medium text-foreground/90 truncate">
              {userName}
            </p>
            <p className="text-[11px] text-muted-foreground">免费版</p>
          </div>
        </div>
      </div>
    </aside>
  );
}
