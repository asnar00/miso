# remote-commands
*programmatic control via external scripts and agents*

The viewer supports remote command execution, enabling external scripts, agents, and automation tools to control the application programmatically.

## Command Types

### Test Commands
Simple commands for testing connectivity and verifying the remote control system is operational.

### Navigation Commands  
Direct the viewer to specific snippets within the miso tree structure using path-based navigation.

**Path Format**: `category/subcategory/item` (e.g., `tools/viewer`, `platforms/macos`)

### Status Commands
Query the current state of the viewer, including current location, loaded content, and operational status.

## Integration Benefits
- **Agent Control**: Enables AI agents to navigate and control the viewer during development workflows
- **Automation**: Supports scripted navigation for demonstrations, testing, and content updates
- **Multi-tool Coordination**: Allows other tools to direct viewer focus based on their operations

## Implementation
Platform-specific implementations handle the actual command reception and processing, while maintaining consistent command semantics across all supported platforms.