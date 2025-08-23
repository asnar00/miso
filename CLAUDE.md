# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`miso` is an experimental system for natural-language programming that represents programs as trees of feature snippets - small natural-language markdown documents describing functionality. It's designed to help end-users (domain experts) write and maintain their own software with the help of engineers and LLM-based coding agents.

## Core Architecture

### Snippet-Based Architecture
- Programs are represented as hierarchical trees of "feature snippets"
- Each snippet is a small markdown document (< 300 words) with a title, emphasized summary, and content
- Snippets are stored as `features/A/B/C.md` for nested features
- Meta-information is stored in `A/B/C/~meta/` folders
- Collections of objects are stored in `A/B/C/~all/` folders

### Key Components

1. **Snippets** (`features/miso/snippets.md`): The core representation format - natural language descriptions of program features
2. **Tools** (`features/miso/tools.md`): Small pieces of runnable code for repeatable tasks
3. **Actions** (`features/miso/actions.md`): Human/agent-followable instructions (not directly executable)
4. **Preferences** (`features/miso/preferences.md`): System-wide settings affecting all tools and actions

### Storage System
- Snippet hierarchy maps directly to filesystem: `A/B/C` → `features/A/B/C.md`
- Meta-folders (`/meta`) store build artifacts, conversations, embeddings, and tool implementations
- Object collections stored in `/all` folders
- Tool implementations go in `A/B/C/meta/code/xxx/` where xxx is language (e.g. `py`)
- Storage preferences defined in `features/miso/preferences/storage.md`

## Development Workflow

The project now has working Python tools implementing the core semantic search functionality:

### Available Tools
- **compute-embedding**: Generates SBERT embeddings for all snippets (Python implementation in `features/miso/tools/all/compute-embedding/meta/code/py/`)
- **search**: Semantic similarity search across snippets (Python implementation in `features/miso/tools/all/search/meta/code/py/`)
- **query**: Q&A system using search + Claude API (Python implementation in `features/miso/tools/all/query/meta/code/py/`)

### Running Tools
```bash
# Generate embeddings for all snippets
python3 features/miso/tools/all/compute-embedding/meta/code/py/compute_embedding.py

# Search for relevant snippets
python3 features/miso/tools/all/search/meta/code/py/search.py miso "your question"

# Query the system (requires ANTHROPIC_API_KEY in .env file)
python3 features/miso/tools/all/query/meta/code/py/query.py miso "your question"
```

### Claude Code Integration
When user types `query [question]`, run the query tool and show just the answer.

### Working with Snippets
- Keep snippets under 300 words
- Start with '#' title and *emphasized* summary
- Limit child snippets to four per parent for simplicity
- Add detail through child snippets rather than editing parent snippets
- Write in user-understandable language

### Experimental Nature
- Each experiment starts fresh or builds on previous work
- Previous experiments are stored in branches
- Main branch is cleared for new experiments
- The current state represents ongoing exploration of "modular specifications"

## System Goals
- Enable better collaboration between users, engineers, and agents
- Create "natural-language normal form" for programs
- Define families of programs with working examples
- Allow dynamic feature modification
- Generate stable implementations across platforms
- "Lift" legacy code into natural-language specifications