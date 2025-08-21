# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`miso` is a natural language programming system that helps domain experts create and maintain software tools using modular specifications. The system represents programs as trees of short markdown specification documents called "snippets" and uses agents to compile these into working code.

This is an experimental project exploring "modular specifications" - natural-language text snippets describing programs. Each experiment starts fresh, with previous work stored in branches.

## Architecture

The system is organized around these core concepts:

### Snippet Tree Structure
- **Tools** (`project/miso/tools/`): Executable programs that can be command-line utilities or interactive applications
- **Actions** (`project/miso/actions/`): Bullet-point instruction lists for performing specific tasks
- **Platforms** (`project/miso/platforms/`): Platform-specific implementation knowledge (macos, web, etc.)
- **Concerns** (`project/miso/concerns/`): Cross-cutting features like visual style, guidelines, storage

### Key Components
- **Build Action** (`project/miso/actions/build.md`): Core process for converting specifications to running code
- **Viewer Tool** (`project/miso/tools/viewer.md`): Navigation interface for browsing snippet trees
- **Platform Knowledge**: MacOS-specific guidance includes using Xcode templates, OSA commands, and OSAscript messaging

## Development Workflow

### Building Tools
When working on tools, follow the build action process:
1. Detect changed files and identify which tool needs building
2. Assemble context from parent snippets, child snippets, and cross-cutting concerns
3. Assemble platform context
4. Create implementation plan and execute in order
5. Test with user and iteratively refine
6. Update specifications and make implementation notes

### Platform-Specific Development
- **MacOS**: Use Xcode project templates rather than building from scratch
- Use OSA commands for building/stopping applications
- Use OSAscript messages for app control
- Implement custom logging to files rather than system logs

### Code Style and Guidelines
- Keep language simple and focused
- Ask when unsure, make reasonable assumptions
- Use Helvetica/sans-serif fonts for visual elements
- Maintain clean, elegant design with proper visual spacing
- Avoid visual clutter and excessive small buttons

### Soft-linking Convention
Use back-ticks to reference other actions or tools (e.g., `hello world`) - this should trigger lookup of suitable actions or tools.

## Common Development Commands

### Building MacOS Tools
- Use the build script: `project/miso/platforms/~macos/build-and-check`
- This script uses OSA commands to trigger Xcode builds and verifies success
- Build logs are located in `~/Library/Developer/Xcode/DerivedData/TOOLNAME-*/Logs/Build/*.xcactivitylog`

### Creating New MacOS Tools
Follow the template cloning process defined in `project/miso/platforms/macos.md`:
```bash
cp -r project/miso/platforms/~macos/template/* project/miso/tools/~TOOLNAME/code/macos/
# Then rename project files and update references
```

### Context Assembly Process
When working with any tool, follow the systematic context gathering from `project/miso/actions/build/assemble-context.md`:
1. Read parent snippets (e.g., `tools/` for a tool)
2. Read the target snippet itself
3. Read all child snippets
4. Read all `concerns/` snippets for cross-cutting requirements

## Project Structure Notes
- No traditional build system (no package.json, Makefile, etc.) - this is a specification-driven system
- Tools are not allowed to invoke external APIs but can be invoked by agents
- Specifications define families of programs rather than single implementations
- Features can be added, removed, or modified at any time through specification updates
- Implemented tools are stored in `~TOOLNAME/` directories alongside their specifications