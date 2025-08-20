# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Miso ("make it so") is an experimental framework for building software using modular specifications - trees of short natural-language text snippets describing programs. This is a specification-first approach where programs are described in natural language before implementation.

## Core Architecture

The project uses a hierarchical structure of markdown files to represent modular specifications:

- **Snippets** (`miso/snippets.md`): Small natural-language markdown documents that describe system components. Each snippet has a title, emphasized summary, and content under 300 words. Snippets can have up to 6 children and reference others via "soft links".

- **Tools** (`miso/tools/`): Computer programs that perform repeatable actions, from CLI utilities to desktop apps. Tools implement features and store code/artifacts in `A/B/C~/imp/**` folders (where `**` is the platform name).

- **Platforms** (`miso/platforms/`): Platform-specific expertise for operating systems, languages, and SDKs. Contains implementation knowledge, tips, and examples.

- **Concerns** (`miso/concerns/`): Cross-cutting features that affect multiple other features. Features can indicate they're affected by concerns using soft-links.

- **Howtos** (`miso/howtos/`): Instructions for agents or users, containing bullet-point action lists. Can invoke specific actions using `inline-code` notation.

## Development Workflow

Since this is a specification-based project without traditional code files yet:

1. **Adding features**: Create new markdown snippets under the appropriate category
2. **Implementing tools**: Place implementations in `toolname~/imp/platform/` structure
3. **Documenting concerns**: Add markdown files to `miso/concerns/` for cross-cutting features
4. **Creating howtos**: Document procedures in `miso/howtos/` as action lists

## Key Principles

- Each experiment starts fresh or builds on previous ones (stored in branches)
- Main branch is always cleared for new experiments
- Specifications define families of programs plus working examples
- Features should be modifiable by users at any time
- Implementations should be stable and predictable across platforms