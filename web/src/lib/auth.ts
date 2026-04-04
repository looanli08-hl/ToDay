export function getAuthCallbackUrl() {
  if (typeof window === "undefined") {
    return "/auth/callback";
  }

  return `${window.location.origin}/auth/callback`;
}

export function isExistingUserSignUp(identities: ArrayLike<unknown> | null | undefined) {
  return Array.isArray(identities) && identities.length === 0;
}

export function getFriendlyAuthError(message: string) {
  const normalized = message.toLowerCase();

  if (normalized.includes("user already registered")) {
    return "该邮箱已注册，请直接登录";
  }

  if (normalized.includes("email not confirmed")) {
    return "请先验证你的邮箱";
  }

  if (normalized.includes("rate limit")) {
    return "发送过于频繁，请稍后再试";
  }

  return message;
}
