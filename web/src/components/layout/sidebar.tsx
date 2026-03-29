"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import {
  LayoutDashboard,
  Clock,
  MessageSquare,
  Monitor,
  Settings,
  Sparkles,
} from "lucide-react";

const navItems = [
  { href: "/dashboard", label: "概览", icon: LayoutDashboard },
  { href: "/dashboard/timeline", label: "时间线", icon: Clock },
  { href: "/dashboard/screen-time", label: "屏幕时间", icon: Monitor },
  { href: "/dashboard/echo", label: "Echo", icon: Sparkles },
  { href: "/dashboard/settings", label: "设置", icon: Settings },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="flex h-screen w-64 flex-col border-r border-border/40 bg-card">
      {/* Logo */}
      <div className="flex h-16 items-center gap-3 px-6">
        <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-orange-400 to-orange-500">
          <span className="text-sm font-bold text-white">T</span>
        </div>
        <span className="text-lg font-semibold tracking-tight">ToDay</span>
      </div>

      {/* Navigation */}
      <nav className="flex-1 space-y-1 px-3 py-4">
        {navItems.map((item) => {
          const isActive =
            pathname === item.href ||
            (item.href !== "/dashboard" && pathname.startsWith(item.href));
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                isActive
                  ? "bg-primary/10 text-primary"
                  : "text-muted-foreground hover:bg-accent hover:text-accent-foreground"
              )}
            >
              <item.icon className="h-4 w-4" />
              {item.label}
            </Link>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="border-t border-border/40 p-4">
        <div className="flex items-center gap-3">
          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-muted">
            <span className="text-xs font-medium">L</span>
          </div>
          <div className="flex-1 truncate">
            <p className="text-sm font-medium">Looan</p>
            <p className="text-xs text-muted-foreground">免费版</p>
          </div>
        </div>
      </div>
    </aside>
  );
}
