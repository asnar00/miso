---
skill_name: post-debug-cleanup
description: Update feature specs and implementation docs to accurately reflect debugging work. Use after completing a feature implementation that required multiple rounds of debugging and iteration.
trigger_phrases:
  - "post-debug cleanup"
  - "update the docs"
  - "document what we did"
  - "clean up the implementation docs"
delegate: false
---

# Post-Debug Cleanup Skill

## Purpose

After implementing a feature through multiple debugging iterations, this skill updates the feature specification and implementation documents to accurately reflect the final working implementation, ensuring knowledge isn't lost.

## When to Use

Use this skill when:
- You've completed a feature implementation after multiple debugging rounds
- The original spec/implementation docs no longer match what was actually built
- You want to capture all the specific details (UI measurements, gesture thresholds, API endpoints, etc.)
- The conversation is about to end and you want to preserve the work

## Skill Instructions

### Step 1: Identify the Feature

Ask the user which feature was implemented, or infer from context. Determine:
- Feature path (e.g., `apps/firefly/features/posts/explore-posts`)
- Which platforms were implemented (ios, eos, py)

### Step 2: Review the Implementation

Read the actual product code files that were modified during the implementation:
- Use git to see what files changed
- Read the final versions of those files
- Note specific details: exact measurements, colors, thresholds, API endpoints, etc.

### Step 3: Update Feature Spec (feature.md)

The feature spec should be:
- Written for users, not developers
- <300 words
- Simple language, no jargon
- Start with `# feature name` and `*one-line summary*`
- Use `**Bold Headings**:` for subsections if needed

Update the spec to accurately describe:
- What the user sees
- How the user interacts with it
- What happens when they do things
- Visual details users will notice (colors, icons, positions)

### Step 4: Update Pseudocode (imp/pseudocode.md)

Update the platform-agnostic pseudocode to reflect:
- Core data structures actually used
- Functions that were implemented
- Visual specifications (exact sizes, colors, positions)
- Gesture handling (exact thresholds)
- API endpoints with correct paths and response formats
- Patching instructions showing exactly what to modify

Include specific numbers and measurements discovered during debugging.

### Step 5: Update Platform Implementation (imp/{platform}.md)

For each platform implemented, update the implementation doc with:
- Complete, accurate code examples from the actual product files
- Exact file paths
- Full function implementations (not stubs)
- All the details: gesture recognizers, animations, error handling
- API response structures with correct field names
- Visual design specs (colors as RGB values, sizes in points, etc.)

### Step 6: Verify Accuracy

Double-check:
- Code examples compile/work as shown
- API endpoints match what the server actually provides
- Measurements match what's in the actual code
- No outdated information from earlier debugging attempts

## Example Usage

**User says:** "let's do post-debug cleanup for explore-posts"

**Skill response:**
1. Find feature at `apps/firefly/features/posts/explore-posts/`
2. Check git diff to see what files changed
3. Read PostsView.swift, PostView.swift, ChildPostsView.swift, Post.swift
4. Update `explore-posts.md` with user-facing description
5. Update `imp/pseudocode.md` with accurate specs (e.g., "swipe threshold: 30pt", "arrow size: 32pt")
6. Update `imp/ios.md` with complete code from actual files
7. Verify all details are accurate

## Key Principles

1. **Accuracy over completeness**: Show what actually works, not what was attempted
2. **Specificity**: Include exact numbers, not ranges or "approximately"
3. **Working code**: Code examples should be copy-pasteable and functional
4. **User perspective**: Feature specs describe user experience, not implementation
5. **Platform separation**: Keep platform-agnostic logic in pseudocode, platform-specific in platform docs

## Files to Update

For feature at path `apps/firefly/features/posts/explore-posts/`:

1. `explore-posts.md` - User-facing feature spec
2. `imp/pseudocode.md` - Platform-agnostic implementation
3. `imp/ios.md` - iOS implementation (if applicable)
4. `imp/eos.md` - Android implementation (if applicable)
5. `imp/py.md` - Python implementation (if applicable)

## Success Criteria

After running this skill:
- Feature spec accurately describes the user experience
- Pseudocode matches the actual implementation logic
- Platform docs contain working, tested code
- Another developer could implement the feature from the docs
- No obsolete information from failed debugging attempts remains
