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

## Development Workflow

The project currently exists as a specification-only system. When working with this codebase:

1. Follow the established snippet naming and storage conventions
2. Keep specifications concise and focused on functionality summaries
3. Use child snippets to add detail rather than editing parent snippets
4. Tool implementations should be organized by language/platform in the `run/` directory

## File Conventions
- All snippet titles and headings use lowercase
- Snippets start with `#` title and *emphasized* summary line
- Features and snippets are referenced interchangeably by name (e.g., `miso`, `miso\snippets`)