---
trigger: always_on
description: TruthWorld core engineering principles, pre/post coding workflows, security rules, and quality standards
---

# TruthWorld Engineering Rules

## Project
TruthWorld is a platform focused on:
- AI-powered fact checking
- Content dubbing/localization
- Creator monetization
- Discover/search
- Channels/topics
- User-generated content

## Engineering Principles
- Never rewrite working systems unnecessarily.
- Inspect existing architecture before modifying code.
- Preserve backward compatibility.
- Prefer small, testable changes.
- Do not introduce duplicate functionality.
- Reuse existing services/components whenever possible.
- Never remove functionality without explicit approval.

## Before Coding
1. Understand the relevant architecture.
2. Search for existing implementations.
3. Identify dependencies.
4. Identify affected APIs/database schemas.
5. Produce an implementation plan.
6. Then implement.

## After Coding
- Run relevant tests.
- Run type checking.
- Run linting.
- Check build.
- Review changed files.
- Look for regressions.
- Report exactly what changed.

## Security
Treat authentication, authorization, payments, user data, copyright, moderation, uploads and external APIs as sensitive.

- Never expose secrets.
- Never hard-code credentials.
- Validate all user-controlled input.

## TruthWorld Quality Standard
- **Production-grade code only**: Every feature must be fully wired and production-ready.
- **Zero Mock Data Policy**: Absolutely never introduce mock arrays, dummy records, simulated endpoints, fake IDs (`acct_mock_`, `po_mock_`, etc.), or artificial delay stubs into production code. All logic must integrate with authentic Firestore collections, real Cloud Functions, verified database schemas, and authoritative external APIs.
- **Zero Raw Developer Error Policy**:
  - Never show raw exceptions, stack traces, developer logs, or technical error messages to end users (e.g., never display `$e`, `e.toString()`, `[cloud_firestore/...]`, `SocketException`, `PlatformException`, `Null check operator`, etc. in UI feedback).
  - Always translate errors into clear, friendly, standard English explanations with actionable advice (e.g. "Unable to load videos. Please check your connection and try again." instead of "Failed to load: $e").
  - Log raw exceptions internally with `ErrorHandler.log(e)` or `logger.error(...)` for debugging and diagnostic tracking.
  - Never display aggressive or technical titles like `"Error"`, `"Input Error"`, or `"Validation Error"` in snackbars or toasts. Use clean descriptive titles or omit the title when the message speaks for itself.
- **File & Code Optimization**:
  - Keep files clean, modular, and performance-optimized.
  - Avoid bloated monolithic files; break down complex interfaces and controllers into focused, single-responsibility components.
  - Optimize memory and runtime latency: eliminate unnecessary memory allocations, minimize GC churn, enforce strict stream/timer disposal, and eliminate frame jank.
- **Zero Invisible Elements & High Contrast Policy**:
  - Always enforce strong visual contrast (WCAG AA compliant).
  - Never pair white/brand backgrounds (`AppColors.brand`, `Colors.white`) with white foregrounds, white icons, white text, or white loading indicators. On white surfaces, all text, icons, and indicators MUST be black (`Colors.black`).
  - Always run `flutter test test/core/ui_contrast_guard_test.dart` to verify zero contrast violations.
- Do not claim something works unless it has been verified.
