# Auth Flow Redesign for First User Launch

## Context

ToDay is preparing for its first batch of users. The current auth pages are functional but need improvements to provide a professional first impression and handle the email verification flow correctly.

Current state:
- Email/password registration and login work via Supabase
- OAuth (GitHub/Google) buttons exist but are broken (PKCE issue on Vercel)
- No post-registration email verification guidance
- No forgot password flow
- Supabase "Confirm email" is enabled — users must verify email before first login

## Goals

1. Registration/login flow works end-to-end with email verification
2. Professional feel — not fancy, but correct and polished
3. Prepare layout for future phone number auth (China: SMS verification code)
4. Remove broken features (OAuth) to avoid bad first impressions

## Non-Goals

- UI visual overhaul (separate effort later)
- OAuth fix (separate effort, add back when working)
- Phone/SMS auth implementation (blocked on SMS provider setup)
- iOS auth changes (keep as-is for now)

## Flow

### New User Registration
```
Register page (/auth/register)
  → Submit (email + password + name)
  → Supabase signUp()
  → Redirect to /auth/verify?email=xxx@email.com
  → User checks email, clicks confirmation link
  → Supabase redirects to /auth/callback
  → Callback processes confirmation, redirects to /dashboard
```

### Existing User Login
```
Login page (/auth/login)
  → Submit (email + password)
  → signInWithPassword()
  → Success → redirect to /dashboard
  → Error "Email not confirmed" → show prompt + resend button
```

### Forgot Password
```
Login page → click "Forgot password"
  → /auth/reset-password
  → Enter email → resetPasswordForEmail()
  → Show "check your email" message
  → User clicks link in email
  → Redirect to /auth/update-password
  → Enter new password → updateUser({ password })
  → Redirect to /dashboard
```

## Pages

### 1. Register Page (`/auth/register`) — MODIFY

Changes from current:
- Remove GitHub and Google OAuth buttons
- Remove OAuth divider ("or use email")
- Add bottom text: "Use phone number (coming soon)" — gray, non-clickable
- Keep: name, email, password fields
- Keep: link to login page
- On successful signUp: redirect to `/auth/verify?email={email}` instead of `/dashboard`

### 2. Login Page (`/auth/login`) — MODIFY

Changes from current:
- Remove GitHub and Google OAuth buttons
- Remove OAuth divider
- Add "Forgot password?" link below password field
- Add bottom text: "Use phone number (coming soon)" — gray, non-clickable
- Keep: email, password fields
- Keep: link to register page
- Handle unverified email error: show message + resend verification button

### 3. Verify Email Page (`/auth/verify`) — NEW

- Route: `/auth/verify`
- Read `email` from query params
- Display:
  - Icon (envelope or checkmark animation)
  - "Verification email sent"
  - "We sent a link to {email}. Click it to activate your account."
  - "Resend email" button (calls `supabase.auth.resend({ type: 'signup', email })`)
  - "Back to login" link
- Resend button has cooldown (60 seconds) to prevent spam

### 4. Auth Callback (`/auth/callback`) — MODIFY

Current implementation handles OAuth PKCE exchange. Needs to also handle:
- Email confirmation redirects from Supabase
- Password reset redirects
- Parse `type` param from Supabase to determine flow
- On email confirmation: redirect to `/dashboard`
- On password reset: redirect to `/auth/update-password`

### 5. Reset Password Page (`/auth/reset-password`) — NEW

- Route: `/auth/reset-password`
- Email input field
- Submit calls `supabase.auth.resetPasswordForEmail(email, { redirectTo: '/auth/callback' })`
- After submit: show "Check your email for reset link" message
- "Back to login" link

### 6. Update Password Page (`/auth/update-password`) — NEW

- Route: `/auth/update-password`
- New password input (min 6 chars)
- Confirm password input
- Submit calls `supabase.auth.updateUser({ password })`
- On success: redirect to `/dashboard`

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Registration with existing email | Show "This email is already registered" |
| Login with wrong password | Show "Invalid email or password" |
| Login with unverified email | Show "Please verify your email first" + resend button |
| Resend email cooldown | Disable button for 60s, show countdown |
| Network error | Show "Connection error, please try again" |
| Password too short | Client-side validation, min 6 chars |
| Passwords don't match (reset) | Client-side validation before submit |

## Technical Notes

- All pages are client-side (`"use client"`) using `@supabase/supabase-js`
- Auth callback needs to handle both `code` (OAuth/confirmation) and `type` params
- Supabase email templates can be customized later in Dashboard → Authentication → Email Templates
- The "coming soon" phone auth text is a static placeholder — no functionality behind it

## File Changes Summary

| File | Action |
|------|--------|
| `web/src/app/auth/register/page.tsx` | Modify — remove OAuth, fix redirect |
| `web/src/app/auth/login/page.tsx` | Modify — remove OAuth, add forgot password |
| `web/src/app/auth/verify/page.tsx` | Create — email verification guidance |
| `web/src/app/auth/callback/route.ts` | Modify — handle email confirmation + password reset |
| `web/src/app/auth/reset-password/page.tsx` | Create — forgot password form |
| `web/src/app/auth/update-password/page.tsx` | Create — new password form |
