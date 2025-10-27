# Skills with Delegation

This directory contains Claude Code skills for miso platform development. Skills can be executed in two modes: **inline** or **delegated**.

## Delegation Pattern

### Why Delegate?

When Claude invokes a skill, the SKILL.md content loads into the foreground context and Claude executes the instructions directly. For complex multi-step skills, this can consume significant context tokens.

**Delegation** allows Claude to spawn an `instruction-follower` sub-agent that:
- Executes the skill autonomously
- Uses its own context budget
- Only returns the final result
- **Saves 80-90% of foreground context**

### How It Works

Skills with `delegate: true` in their frontmatter should be automatically delegated:

```yaml
---
name: ios-deploy-usb
description: Build and deploy iOS app...
delegate: true
---
```

When Claude encounters this flag:
1. Skill is invoked and loaded (small context cost)
2. Claude checks for `delegate: true` in frontmatter
3. Claude uses Task tool with `subagent_type="instruction-follower"`
4. Provides path to SKILL.md: `.claude/skills/skill-name/SKILL.md`
5. Agent executes autonomously
6. Only final report returns to foreground

### Example Invocation

```python
# User asks: "Deploy to iPhone"
# Claude invokes skill
Skill(command="ios-deploy-usb")

# Skill loads, Claude sees delegate: true
# Claude immediately delegates:
Task(
    subagent_type="instruction-follower",
    description="Deploy iOS app to device",
    prompt="Follow the instructions in .claude/skills/ios-deploy-usb/SKILL.md to build and deploy the iOS app to the connected iPhone."
)

# Agent executes, returns result
# Claude summarizes for user
```

## Which Skills Use Delegation?

### Delegated Skills (delegate: true)

Complex multi-step processes that benefit from delegation:

**Deployment**:
- `ios-deploy-usb` - iOS USB deployment
- `eos-deploy-usb` - Android USB deployment
- `py-deploy-remote` - Remote server deployment

### Inline Skills (no delegate flag)

Simpler skills that are fine to execute directly:

**App Control**:
- `ios-restart-app`
- `ios-stop-app`
- `eos-restart-app`
- `eos-stop-app`
- `py-start-local`
- `py-stop-local`

**Monitoring**:
- `ios-watch-logs`
- `eos-watch-logs`
- `py-server-logs`

**Screen Capture**:
- `iphone-screen-capture`
- `eos-screen-capture`

**Project Editing**:
- `ios-add-file`

## Adding Delegation to New Skills

When creating a new skill, consider delegation if:
- Skill has 5+ distinct steps
- Involves multiple tool calls (bash, read, edit)
- Takes significant time to execute
- Could benefit from autonomous execution

Simply add `delegate: true` to the frontmatter:

```yaml
---
name: my-complex-skill
description: Does something complex...
delegate: true
---
```

## Context Savings

**Without delegation** (inline execution):
- Skill SKILL.md: ~2KB
- Claude's execution: 10-50KB+ (tool calls, results, thinking)
- **Total: ~12-52KB**

**With delegation**:
- Skill SKILL.md: ~2KB
- Task invocation: ~1KB
- Agent's final report: ~1-2KB
- **Total: ~4-5KB**

**Savings: 80-90% context reduction**

## Best Practices

1. **Use delegation for deployment skills** - These are complex and benefit most
2. **Keep simple skills inline** - Restart, stop, logs are quick and simple
3. **Test both modes** - Ensure delegated skills work autonomously
4. **Document clearly** - SKILL.md must be complete for autonomous execution
5. **Provide examples** - Show expected output in SKILL.md

## Testing Delegation

To test a delegated skill in a new session:

1. Invoke the skill normally (e.g., "Deploy to iPhone")
2. Claude should detect `delegate: true`
3. Claude should use Task tool with instruction-follower
4. Agent executes and returns result
5. Claude summarizes for user

Watch for:
- Correct Task tool invocation
- Agent successfully reading SKILL.md
- Autonomous execution without Claude's intervention
- Clean result report back to foreground

## Skill Naming Convention

- `ios-*` - iOS platform skills
- `eos-*` - Android/e/OS platform skills
- `py-*` - Python/server skills
- `iphone-*` - iPhone-specific tools (legacy, consider renaming to ios-*)

## Future Enhancements

Possible improvements:
- Auto-detect complexity and delegate automatically
- Add `allowed-tools` restriction for read-only skills
- Create skill templates for common patterns
- Add skill dependencies (skill A requires skill B)
