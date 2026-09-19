# Miso

Miso is a system for building software through natural-language specifications. The core idea: represent programs as human-readable feature trees, not code. Code is generated from specs, not written directly.

## Feature Structure

Each feature is a folder containing:

- **spec.md** — the contract: actors, flows, edge cases, requirements
- **user.md** — per-role communication: what we say to each user, error messages, help text
- **test.md** — verification: workflows, action sequences, expected outcomes
- **imp.md** — language-agnostic pseudocode: data classes (DEFINE/EXTEND), functions (DEFINE/EXTEND), server/client behaviour in one place
- **howto.md** — quick reference: "to do X, call Y" (derived from imp.md)
- **ios.md, android.md, py.md** — generated platform code

The flow: spec.md → user.md / test.md → imp.md → howto.md → platform code → monolithic product.

## Composition Rules

Features compose through DEFINE and EXTEND:

- DEFINE creates new classes or functions
- EXTEND adds new data to existing classes, or wraps existing functions
- Extension order follows feature creation order
- UI is expressed as intent functions (`get_user_email()`), not layout descriptions

## User Personalization

All features ship in every build. Each user has server-side config:

- **Feature toggles** — which features are enabled
- **Settings** — constants that tune each feature (font sizes, colors, etc.)

Users can change anything that doesn't affect other users. Their tweaks can be promoted to defaults.

## Feedback Loop

Users report issues via in-app feedback. The app captures a 60-second video buffer, timeline of actions, config snapshot, and optional front-camera (for consenting test users). An agent interprets the feedback and routes it:

**Tier 1 — Settings (instant):** Safe changes like font sizes, colors, timing. Agent updates user's config, pushes immediately. No app update required.

**Tier 2 — Code (queued):** User requests local functionality changes ("I want X to work differently"). Agent creates a user-scoped sub-feature, generates code, queues for next build. Feature ships enabled only for that user until promoted.

**Tier 3 — Human review:** Changes affecting other users, security, or architectural decisions. Agent escalates to a human (developer, support, or domain expert). Human decides, agent executes and captures the decision back into the spec tree.

The boundary: users can change anything that doesn't affect others. Beyond that, a human is in the loop.

## Queryable Spec Tree

All .md files are embedded in a vector database. The agent queries the tree to answer questions, route tasks, and understand context. Query routing: howto.md for "how do I?", user.md for "what do we say?", spec.md for "why?", imp.md for "how is it built?". If the tree lacks an answer, the agent escalates to a human — and captures the answer back into the tree.

## Staleness Detection

Files have a dependency chain: spec.md → user.md / test.md → imp.md → howto.md → platform code. If a parent file is newer than its child, the child is potentially stale. This is a cheap timestamp check — no agent required. When staleness is detected, the agent (or human) is prompted to update the child.

## Test Composition

Tests follow the same DEFINE/EXTEND pattern as code. A parent feature defines a high-level workflow (e.g., "user signs in"). Child features extend it with their steps and expectations (e.g., "enter 4-digit code"). When tests run, the workflow expands based on which features are enabled — same test, different paths.

## Verification Loop

For each feature change, the agent runs a tight loop on all platforms in parallel:

1. **Deploy** — install app on simulator/emulator
2. **Reset** — clear state via `/reset` endpoint
3. **Execute** — run action sequence via test server (`/ui/tap`, `/ui/type`, `/ui/wait`)
4. **Capture** — collect logs, screenshots, timing, state
5. **Compare** — check against expected outcomes

Target: < 15 seconds per test. Simulators for fast parallel iteration; physical devices for final verification before release.

## Stepwise Code Generation

Building "all-in-one" fails — too many things can break, context overload, compounding errors. Instead, build stepwise: each step is a small delta with its own test. The chain becomes: imp.md → plan.md → platform code. imp.md says *what* to build; plan.md says *how*, step-by-step per platform. Each step: implement delta, build, deploy, test. Pass → next step. Fail → fix and retry with small blast radius.

## Builder and Validator Agents

Two agent roles with different mindsets:

**Builder:** Implements the feature, runs tests, confirms "it works."

**Validator:** Plays the user. Reviews the work *without* looking at implementation. Uses only the UI. Asks: "Would a real user be happy? Is this intuitive? What happens if I try to break it?"

Escalation ladder: Builder completes → Validator reviews → Pass? Ship. Minor issues? Builder fixes. Major issues or repeated failures? Escalate to human. Catastrophic risk (data loss, security)? Human must approve before shipping.

## Agent Features

Not all features generate code. Some generate **agent.md** — runnable instructions for an agent (or human) to follow. Examples: deploying to TestFlight, resetting a user's password, running a demo. Same structure (spec.md, user.md, test.md, imp.md) but output is a procedure, not compiled code. The agent executes step-by-step, verifying each step, just like code generation.

## Adaptive Learning

A feature handles cases 1..N. When case N+1 fails, we learn:

1. **Capture** — input, expected vs actual outcome, logs
2. **Diagnose** — what's new? bug (should work) or gap (never specified)?
3. **If gap → Learn** — create sub-feature to handle new case
4. **If bug → Fix** — update existing feature
5. **Verify** — cases 1..N still pass (regression), case N+1 now passes

Every learned case becomes a permanent test. The feature tree grows organically from real-world encounters. This applies to both code features and agent features.

## Bidirectional Workflow

Two modes of working:

**Top-down (spec→code):** spec.md → user.md → test.md → imp.md → plan.md → code. Good for new features with clear requirements.

**Bottom-up (code→spec):** Iterate on code until it works, then reconcile upward. Good for exploration, "I'll know it when I see it", visual/UX work.

Bottom-up is faster in the moment but creates debt — code is ahead of spec. After bottom-up iteration, reconcile: agent reads the working code and regenerates imp.md → test.md → user.md → spec.md. Human reviews and approves. Staleness detection works both directions: spec newer than code = code stale; code newer than spec = spec stale.

## Space vs Point

The spec defines a *space* of valid programs; generated code is one *point* in that space. Fresh rebuilds jump to a new point — valid, but potentially different. The previous point encodes implicit knowledge (timing, feel, UX flourishes) that may not be in the spec. Before regenerating, capture: "What do you LIKE about current? What ANNOYS you?" Update spec with fixes, preserve the keeps. Compare new point against both spec (tests) and previous point (behavioral diff, golden demo recordings).

## Capturing Subtle Quality (Open Question)

For no-human-in-loop iteration, we need to capture subtle stuff: timing, feel, flow, "rightness." Possible approaches: exhaustive specification (hard), golden reference with tolerance (medium), LLM as taste judge (interesting but uncertain), or capture human micro-reactions during demos. Likely a hybrid: LLM judges, flags uncertainty, human reviews flagged items. This needs experimentation to figure out what actually works.

## Preference Learning

Refinement loops ("make the button bigger", "bolder text") should be learning opportunities. Two levels: **specific** ("sign-in button is 48pt") goes into the feature spec; **general** ("Ash prefers larger tap targets") goes into a root-level `preferences.md` or style guide. The agent consults preferences *before* building, as a prior that shapes generation. Learning can be explicit ("remember this as a general preference?") or inferred from patterns ("you've increased button size 3 times — want me to default to larger?"). Preferences become part of the queryable tree, so the agent builds "the right thing" without repeated refinement.
