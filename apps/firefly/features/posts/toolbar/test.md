# toolbar test
*test specification for toolbar feature*

## UI Elements to Register

| Element ID | Description | Action |
|------------|-------------|--------|
| toolbar-makepost | Make Post button (chat bubble icon) | Switch to makePost explorer |
| toolbar-search | Search button (magnifying glass icon) | Switch to search explorer |
| toolbar-users | Users button (two people icon) | Switch to users explorer |

## Logging Points

Logger automatically adds `[APP]` prefix. Filter with: `adb logcat | grep "[APP] [Toolbar]"`

| Log Message | When Emitted |
|-------------|--------------|
| `[Toolbar] Appeared` | Toolbar view first renders |
| `[Toolbar] Explorer changed to: makePost` | User switches to makePost explorer |
| `[Toolbar] Explorer changed to: search` | User switches to search explorer |
| `[Toolbar] Explorer changed to: users` | User switches to users explorer |
| `[Toolbar] Reset makePost view` | User taps makePost when already active |
| `[Toolbar] Reset search view` | User taps search when already active |
| `[Toolbar] Reset users view` | User taps users when already active |

## Test Sequences

### test-toolbar-appear
*Verify toolbar appears on app launch*

```
1. restart app
2. expect "[Toolbar] Appeared"
```

### test-toolbar-switch-explorers
*Verify switching between all three explorers*

```
1. restart app
2. expect "[Toolbar] Appeared"
3. tap toolbar-search
4. expect "[Toolbar] Explorer changed to: search"
5. tap toolbar-users
6. expect "[Toolbar] Explorer changed to: users"
7. tap toolbar-makepost
8. expect "[Toolbar] Explorer changed to: makePost"
```

### test-toolbar-reset-makepost
*Verify double-tap on makePost resets the view*

```
1. restart app
2. expect "[Toolbar] Appeared"
3. tap toolbar-makepost
4. expect "[Toolbar] Reset makePost view"
```

### test-toolbar-reset-search
*Verify double-tap on search resets the view*

```
1. restart app
2. expect "[Toolbar] Appeared"
3. tap toolbar-search
4. expect "[Toolbar] Explorer changed to: search"
5. tap toolbar-search
6. expect "[Toolbar] Reset search view"
```

### test-toolbar-reset-users
*Verify double-tap on users resets the view*

```
1. restart app
2. expect "[Toolbar] Appeared"
3. tap toolbar-users
4. expect "[Toolbar] Explorer changed to: users"
5. tap toolbar-users
6. expect "[Toolbar] Reset users view"
```

## Running Tests Manually

```bash
# Setup port forwarding (once per session)
adb forward tcp:8081 tcp:8081

# Verify elements are registered
curl http://localhost:8081/test/list-elements

# Tap elements
curl -X POST "http://localhost:8081/test/tap?id=toolbar-search"

# Check logs
adb logcat -d | grep "\[Toolbar\]"

# Restart app to reset state
adb shell am force-stop com.miso.noobtest
adb shell am start -n com.miso.noobtest/.MainActivity
```

## Notes

- Default explorer on app launch is `makePost`
- Switching TO an explorer logs "Explorer changed to: {name}"
- Tapping the ACTIVE explorer logs "Reset {name} view"
- State is preserved when switching between explorers (no log when returning to a previously visited explorer)
