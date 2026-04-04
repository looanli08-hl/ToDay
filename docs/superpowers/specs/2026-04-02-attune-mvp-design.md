# Attune MVP Design Spec

> Consolidated from PRODUCT_SPEC.md — this is the implementation-ready reference.
> Full product vision: /Users/looanli/Projects/ToDay/PRODUCT_SPEC.md

## Goal
Build a Chrome extension where Echo (AI companion) lives in the Side Panel, sees what users watch on YouTube, and interacts like a browsing buddy.

## Architecture
Chrome extension with Side Panel UI, YouTube content script for deep perception, enhanced background service worker for universal perception, and server-side Echo brain (DeepSeek API + Supabase memory).

## Current State
- Extension: basic session tracking (domain/title/time), idle detection, sync via sync_token, popup UI
- Web: Next.js + Supabase auth + Echo chat (DeepSeek) + dashboard + screen-time analytics
- No Side Panel, no content scripts, no context-aware Echo
