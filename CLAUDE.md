# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`miso` ("make it so") is a system for creating software tools using natural language specifications. The project represents software as a feature-modular specification using short markdown snippets arranged in a tree structure.

## Architecture

### Specification Structure
- All specifications live in the `spec/` directory
- Snippets follow a hierarchical naming convention:
  - `spec/A.md` for snippet `A`
  - `spec/A/B.md` for snippet `A/B`  
  - `spec/A/B/C.md` for snippet `A/B/C`
- Each snippet starts with a `#` title followed by an *emphasized* single-line summary
- Snippets are kept concise (250-300 words max)

### Tools Structure
- Tool specifications are stored in `spec/miso/tools/`
- Each tool should have a `pseudocode.md` file with step-by-step implementation instructions
- Runnable implementations go in `run/[tool-name]/[language]/`
  - Example: `run/hello/py/` for Python implementation
  - Example: `run/hello/sh/` for shell script implementation

### Core Components
- `spec/miso.md` - Main project specification
- `spec/miso/snippets.md` - Snippet conventions and storage rules
- `spec/miso/tools.md` - Tool structure and organization
- `spec/miso/tools/hello.md` - Example tool specification

## Tool Invocation System

**IMPORTANT**: When the user types a tool name (like `build` or `hello`), follow these invocation rules:

1. Check `run/[tool]/` for code implementations (py/, sh/, cpp/, etc.)
2. If code implementation exists, run the most recent one
3. If no code exists, execute the instructions in `run/[tool]/pseudocode.md`

### Examples:
- User types `hello` → Check `run/hello/py/hello.py` exists → Run: `python3 run/hello/py/hello.py`
- User types `build` → No code in `run/build/py/` → Execute steps from `run/build/pseudocode.md`

This creates a seamless experience where tools can exist as pseudocode, compiled code, or transition between states.

## The Miso System in Action

This repository demonstrates a complete specification-to-implementation pipeline:

1. **Specifications drive everything** - Tools exist first as natural language descriptions in `spec/miso/tools/`
2. **Build compiles specs to working code** - The `build` tool reads specifications and generates both pseudocode and implementations
3. **Self-hosting and self-improving** - Build follows its own specification system and can evolve itself
4. **Testing ensures quality** - Generated tools are validated against their specifications and refined until they work correctly

The system creates a feedback loop where:
- Natural language specifications become executable tools
- Tools can be refined by updating their specifications
- The system documents its own evolution and bug fixes
- Everything remains traceable from intent to implementation

## Development Workflow

When working with this codebase:

1. Follow the established snippet naming and storage conventions
2. Keep specifications concise and focused on functionality summaries  
3. Use child snippets to add detail rather than editing parent snippets
4. Tool implementations should be organized by language/platform in the `run/` directory
5. Use the tool invocation system above when users request tool execution
6. **Run `build` after specification changes** - Let the system regenerate and test implementations
7. **Verify tools work correctly** - The system will test tools but always validate the results match expectations

## File Conventions
- All snippet titles and headings use lowercase
- Snippets start with `#` title and *emphasized* summary line
- Features and snippets are referenced interchangeably by name (e.g., `miso`, `miso/snippets`)