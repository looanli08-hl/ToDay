"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { createClient } from "@/lib/supabase/client";
import { Compass, Settings } from "lucide-react";

const mainNav = [
  { href: "/dashboard", label: "概览", icon: Compass },
];

const bottomNav = [
  { href: "/dashboard/settings", label: "设置", icon: Settings },
];

export function Sidebar() {
  const pathname = usePathname();
  const [userName, setUserName] = useState("...");

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(({ data: { user } }: { data: { user: any } }) => {
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
    <aside className="flex h-screen w-[240px] flex-col border-r border-border/30 bg-[var(--sidebar)]">
      {/* Logo */}
      <div className="px-5 pt-6 pb-4">
        <div className="flex items-center gap-1">
          <span className="font-display text-xl text-foreground tracking-tight">Attune</span>
          <span className="text-primary text-xl">.</span>
        </div>
      </div>

      {/* Main Navigation */}
      <nav className="flex-1 space-y-0.5 px-3 pt-2">
        {mainNav.map((item) => {
          const isActive =
            pathname === item.href ||
            (item.href !== "/dashboard" && pathname.startsWith(item.href));
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-xl px-3 py-2.5 text-[13px] font-medium transition-all duration-200",
                isActive
                  ? "bg-foreground/[0.06] text-foreground shadow-sm"
                  : "text-muted-foreground hover:bg-foreground/[0.03] hover:text-foreground/70"
              )}
            >
              <item.icon className="h-[18px] w-[18px]" strokeWidth={1.5} />
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
                "flex items-center gap-3 rounded-xl px-3 py-2.5 text-[13px] font-medium transition-all duration-200",
                isActive
                  ? "bg-foreground/[0.06] text-foreground"
                  : "text-muted-foreground hover:bg-foreground/[0.03] hover:text-foreground/70"
              )}
            >
              <item.icon className="h-[18px] w-[18px]" strokeWidth={1.5} />
              {item.label}
            </Link>
          );
        })}
      </div>

      {/* User Profile */}
      <div className="border-t border-border/30 px-4 py-4">
        <Link href="/dashboard/settings" className="flex items-center gap-3 rounded-xl px-1 py-1 hover:bg-foreground/[0.03] transition-all duration-200">
          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-primary/10 text-primary">
            <span className="text-xs font-semibold">
              {userName.charAt(0).toUpperCase()}
            </span>
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-[13px] font-medium text-foreground/80 truncate">
              {userName}
            </p>
            <p className="text-[11px] text-muted-foreground/60">免费版</p>
          </div>
        </Link>
      </div>
    </aside>
  );
}
