import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "隐私政策 — Attune",
  description: "Attune 浏览器扩展及网页服务的隐私政策",
};

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mb-10">
      <h2 className="font-display text-lg text-foreground mb-4 pb-2 border-b border-border/50">
        {title}
      </h2>
      <div className="space-y-3 text-sm text-muted-foreground leading-relaxed">
        {children}
      </div>
    </section>
  );
}

function Item({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex gap-3">
      <span className="mt-1.5 w-1.5 h-1.5 rounded-full bg-primary/60 shrink-0" />
      <p>{children}</p>
    </div>
  );
}

export default function PrivacyPage() {
  const lastUpdated = "2026 年 4 月 1 日";

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border/40 bg-background/80 backdrop-blur-sm sticky top-0 z-10">
        <div className="max-w-2xl mx-auto px-6 h-14 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-1">
            <span className="font-display text-xl text-foreground tracking-tight">Attune</span>
            <span className="text-primary text-xl">.</span>
          </Link>
          <span className="text-xs text-muted-foreground">隐私政策</span>
        </div>
      </header>

      {/* Body */}
      <main className="max-w-2xl mx-auto px-6 py-14">
        {/* Title block */}
        <div className="mb-12">
          <p className="text-xs text-primary font-medium uppercase tracking-widest mb-3">
            Privacy Policy
          </p>
          <h1 className="font-display text-3xl text-foreground mb-4">隐私政策</h1>
          <p className="text-sm text-muted-foreground">
            最后更新：{lastUpdated}
          </p>
        </div>

        {/* Intro */}
        <div className="rounded-2xl bg-card border border-border/30 p-6 mb-10 shadow-sm">
          <p className="text-sm text-foreground/80 leading-relaxed">
            Attune（以下简称"我们"）非常重视你的隐私。本隐私政策说明了 Attune
            浏览器扩展及网页服务（daycho.com）如何收集、使用和保护你的数据。
            <strong className="text-foreground">
              我们的核心原则：你的数据属于你，不属于我们。
            </strong>
          </p>
        </div>

        <Section title="一、我们收集哪些数据 — What We Collect">
          <p>Attune 浏览器扩展仅收集以下最小必要数据：</p>
          <Item>
            <strong className="text-foreground">域名（Domain）</strong>
            ：你访问的网站域名，例如 <code className="bg-muted px-1 rounded text-xs">github.com</code>，用于分类和时长统计。
          </Item>
          <Item>
            <strong className="text-foreground">页面标题（Page Title）</strong>
            ：浏览器标签页的标题，用于展示可读的浏览记录摘要。
          </Item>
          <Item>
            <strong className="text-foreground">访问时长（Duration）</strong>
            ：你在每个域名上停留的时间，用于生成每日浏览时间分析。
          </Item>
          <p className="mt-2 p-3 rounded-xl bg-secondary/60 text-foreground/80 border border-border/30">
            <strong>我们绝不读取页面内容。</strong>
            We never read, store, or transmit the actual content of any webpage you visit —
            no text, no passwords, no form data, no personal information on the page itself.
          </p>
        </Section>

        <Section title="二、我们不收集哪些数据 — What We Never Collect">
          <Item>页面正文内容、输入框内容、密码或表单数据</Item>
          <Item>你的地理位置、IP 地址（后端日志除外，且不关联至用户数据）</Item>
          <Item>Cookie、浏览器指纹或任何跨站追踪标识符</Item>
          <Item>无痕浏览（Incognito）模式下的任何数据——扩展在隐身窗口中不工作</Item>
          <Item>你的联系人、文件、相机或麦克风</Item>
        </Section>

        <Section title="三、数据如何存储 — Data Storage">
          <p>
            扩展默认将所有数据保存在<strong className="text-foreground">本地浏览器存储（chrome.storage.local）</strong>中，不会上传至任何服务器。
          </p>
          <p>
            仅当你在扩展设置中<strong className="text-foreground">主动配置同步令牌（Sync Token）</strong>后，数据才会同步至你的 Attune 账户。同步功能完全可选，随时可以关闭或撤销。
          </p>
          <Item>
            云端数据存储在你的个人 Supabase 数据库实例中，与其他用户数据严格隔离。
          </Item>
          <Item>
            所有数据传输均通过 <strong className="text-foreground">HTTPS / TLS</strong> 加密，符合行业标准（Transport Layer Security）。
          </Item>
          <Item>
            我们不会在自有服务器上保留你的浏览数据副本。
          </Item>
        </Section>

        <Section title="四、数据如何使用 — How We Use Data">
          <Item>生成你的每日、每周浏览时间统计，展示在 Attune 仪表盘上。</Item>
          <Item>为 Echo AI 提供上下文，生成个性化的习惯洞察和生活建议。</Item>
          <Item>识别使用模式，帮助你优化数字生活习惯。</Item>
          <p>
            <strong className="text-foreground">我们不会将你的数据用于广告定向、用户画像出售，或任何与上述目的无关的用途。</strong>
          </p>
        </Section>

        <Section title="五、第三方共享 — Third-Party Sharing">
          <p>
            我们<strong className="text-foreground">不向任何第三方出售、交换或租赁</strong>你的个人数据。
          </p>
          <p>我们使用的基础设施服务商：</p>
          <Item>
            <strong className="text-foreground">Supabase</strong>（数据库与身份认证）——遵循 SOC 2 Type II 标准，数据存储于你所选择的地区。
          </Item>
          <Item>
            <strong className="text-foreground">Vercel</strong>（网页托管）——仅用于 daycho.com 页面的访问日志，不包含用户浏览数据。
          </Item>
          <p>
            如法律程序要求披露数据，我们将在法律允许的范围内提前通知你。
          </p>
        </Section>

        <Section title="六、你的权利 — Your Rights">
          <p>你对自己的数据拥有完整控制权：</p>
          <Item>
            <strong className="text-foreground">查看（Access）</strong>：在 Attune 仪表盘随时查看所有已同步的浏览记录。
          </Item>
          <Item>
            <strong className="text-foreground">导出（Export）</strong>：在账户设置页导出完整数据（JSON 格式）。
          </Item>
          <Item>
            <strong className="text-foreground">删除（Delete）</strong>：在账户设置页一键清除所有云端数据；卸载扩展将清除所有本地数据。
          </Item>
          <Item>
            <strong className="text-foreground">停止同步（Revoke Sync）</strong>：在扩展设置中删除同步令牌，数据将停止上传，历史数据保留直到你主动删除。
          </Item>
        </Section>

        <Section title="七、Chrome 扩展权限说明 — Extension Permissions">
          <p>
            Attune 扩展在 Chrome Web Store 审核时声明了以下权限，以下是每项权限的用途说明：
          </p>
          <Item>
            <code className="bg-muted px-1 rounded text-xs font-mono">tabs</code>
            {" "}— 监听标签页切换事件，记录当前活跃域名和页面标题，用于统计浏览时长。
          </Item>
          <Item>
            <code className="bg-muted px-1 rounded text-xs font-mono">activeTab</code>
            {" "}— 读取当前标签页的 URL，用于域名分类（社交、生产力、娱乐等）。
          </Item>
          <Item>
            <code className="bg-muted px-1 rounded text-xs font-mono">storage</code>
            {" "}— 在本地存储浏览会话数据和用户偏好设置（同步令牌、API 地址等）。
          </Item>
          <Item>
            <code className="bg-muted px-1 rounded text-xs font-mono">alarms</code>
            {" "}— 定时触发数据同步（每 1 分钟一次）和本地缓存清理（每小时一次）。
          </Item>
          <Item>
            <code className="bg-muted px-1 rounded text-xs font-mono">idle</code>
            {" "}— 检测用户空闲状态，在空闲时暂停会话计时，确保时长统计准确。
          </Item>
        </Section>

        <Section title="八、儿童隐私 — Children's Privacy">
          <p>
            Attune 服务不面向 13 岁以下儿童（美国 COPPA 标准）或 14 岁以下儿童（中国《个人信息保护法》标准）。我们不会故意收集未成年人的个人信息。
          </p>
        </Section>

        <Section title="九、政策变更 — Policy Changes">
          <p>
            如我们对本政策进行实质性变更，将通过应用内通知或邮件提前告知你。继续使用本服务即表示接受更新后的政策。本政策历史版本可通过 GitHub 仓库查阅。
          </p>
        </Section>

        <Section title="十、联系我们 — Contact">
          <p>
            如你对本隐私政策有任何疑问，或希望行使上述权利，请通过以下方式联系我们：
          </p>
          <div className="mt-2 p-4 rounded-xl bg-card border border-border/30">
            <p className="text-foreground font-medium mb-1">Attune 团队</p>
            <p>
              邮箱：
              <a
                href="mailto:privacy@daycho.com"
                className="text-primary hover:underline ml-1"
              >
                privacy@daycho.com
              </a>
            </p>
            <p>
              网站：
              <a
                href="https://daycho.com"
                className="text-primary hover:underline ml-1"
                target="_blank"
                rel="noopener noreferrer"
              >
                daycho.com
              </a>
            </p>
          </div>
        </Section>
      </main>

      {/* Footer */}
      <footer className="border-t border-border/40 py-8">
        <div className="max-w-2xl mx-auto px-6 flex flex-col sm:flex-row items-center justify-between gap-3">
          <p className="text-xs text-muted-foreground">
            © 2026 Attune. All rights reserved.
          </p>
          <div className="flex gap-4 text-xs text-muted-foreground">
            <Link href="/privacy" className="hover:text-foreground transition-colors font-medium text-foreground/70">
              隐私政策
            </Link>
            <a
              href="https://daycho.com"
              className="hover:text-foreground transition-colors"
              target="_blank"
              rel="noopener noreferrer"
            >
              daycho.com
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
