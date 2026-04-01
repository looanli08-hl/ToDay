"use client";

import { Card } from "@/components/ui/card";
import { LineChart, Smartphone, Globe } from "lucide-react";
import Link from "next/link";

export default function AnalyticsPage() {
  return (
    <div className="min-h-screen">
      <div className="px-12 pt-12 pb-10">
        <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">
          数据分析
        </h1>
        <p className="text-base text-muted-foreground mt-2">
          发现你的生活规律
        </p>
      </div>

      <div className="px-12 pb-12">
        <Card className="border border-border/40 bg-card rounded-xl p-12">
          <div className="text-center max-w-md mx-auto">
            <div className="mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded-full bg-primary/10">
              <LineChart className="h-8 w-8 text-primary/60" strokeWidth={1.5} />
            </div>
            <h2 className="font-display text-xl text-foreground mb-3">
              积累数据后，这里会展示你的生活规律
            </h2>
            <p className="text-sm text-muted-foreground mb-8 leading-relaxed">
              连接你的手机和浏览器扩展，开始记录生活。Echo 会从数据中发现你自己都没注意到的模式。
            </p>
            <div className="flex justify-center gap-3">
              <Link
                href="/dashboard/connectors"
                className="flex items-center gap-2 rounded-full border border-border/50 px-5 py-2.5 text-sm text-muted-foreground hover:text-foreground hover:border-border transition-colors"
              >
                <Globe className="h-4 w-4" strokeWidth={1.5} />
                安装浏览器扩展
              </Link>
              <Link
                href="/dashboard/settings"
                className="flex items-center gap-2 rounded-full border border-border/50 px-5 py-2.5 text-sm text-muted-foreground hover:text-foreground hover:border-border transition-colors"
              >
                <Smartphone className="h-4 w-4" strokeWidth={1.5} />
                连接手机 App
              </Link>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}
