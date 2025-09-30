# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`miso` ("make it so") is an experimental system for natural-language programming. It explores "modular specifications" - trees of short natural-language markdown files ("snippets") that describe programs.

This is an experimental repository where:
- Each experiment starts from scratch or builds on previous work
- Previous experiments are stored in branches
- The main branch is cleared for new experiments

## Architecture

### Specification Structure

Programs are represented as **feature modular specifications** - hierarchical trees of markdown snippet files.

**Snippet Naming Convention:**
- Every snippet has a unique identifier following the pattern `A/B/C` (subfeature C of subfeature B of feature A)
- Snippet `A/B/C` is stored as file `A/B/C.md`
- Each snippet contains:
  - Title (H1 header)
  - Italicized subtitle/tagline
  - Natural language description (typically under 300 words)

**Implementation Storage:**
- Implementation details for snippet `A/B/C` are stored in `A/B/C/imp/` (reserved folder name)
- Platform-specific code goes in subfolders like `A/B/C/imp/ios/`, `A/B/C/imp/py/`, `A/B/C/imp/android/`
- The `imp` folder can also contain notes, change histories, and other implementation artifacts

### Directory Structure

- `ide/` - Contains the miso tooling specifications
  - `ide/miso.md` - Main specification for the miso system
  - `ide/miso/specifications.md` - Details on how miso represents program specifications
- `apps/` - Contains application specifications built with miso
  - `apps/firefly.md` - Specification for Firefly (semantic search social media)
  - `apps/firefly/test/` - Example test application with iOS implementation structure

## Goals

The miso project aims to:
- Find better ways for users, engineers, and agents to collaborate to build software
- Create a "natural-language normal form" representation of programs
- Define a *family of programs* with working examples
- Allow features to be added, removed, or modified by users at any time
- Output stable, predictable implementations on any platform
- "Lift" existing legacy code into normal form specifications

## Working with Specifications

When working with this codebase:
1. Specifications are the source of truth, not implementation code
2. Code should be regenerated from specifications using Claude Code workflows
3. Specifications should remain platform-agnostic
4. Keep specifications up-to-date so code can be rebuilt from scratch or ported to new platforms