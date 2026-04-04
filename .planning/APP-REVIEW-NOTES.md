# App Review Notes — Unfold

Copy the block below into App Store Connect "Notes for Reviewers" on every submission.

---

## Reviewer Notes Template

Unfold is a passive life-logging app. The app uses Location Always 
authorization to automatically record place visits and activity 
throughout the day while running in the background, even when the 
app is not open.

This is the core feature of the app — without Always authorization, 
background location recording cannot occur and the daily life timeline 
cannot be built.

To test:
1. Grant "Always" location permission during onboarding.
2. Background the app.
3. Move to a new location (or use Xcode Simulator → Debug → Location).
4. Return to the app to see the recorded visit appear in the Today timeline.

Test account: Not required — the app is fully local with no login.

---

## AI Feature Disclosure (if AI features are active in the build)

This build includes AI daily summary features. When the app generates
a daily summary, it sends anonymized activity data (inferred place names
and activity types — not raw GPS coordinates) to Anthropic Claude via
AIProxy for processing. No personally identifying information is transmitted.

The privacy policy at https://looanli08-hl.github.io/ToDay/privacy.html
discloses this processing.

---

## Update Log

| Version | Date | Notes |
|---------|------|-------|
| 0.3.0 | 2026-04-04 | Initial App Review Notes created for Phase 2 |
