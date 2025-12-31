# edit-posts test
*test specification for editing existing posts*

This test covers the minimal edit functionality: editing text fields of existing posts owned by the current user.

## UI Elements to Register

| Element ID | Description | Action |
|------------|-------------|--------|
| edit-button-{postId} | Pencil button (own posts, expanded, not editing) | Enter edit mode |
| cancel-button-{postId} | Undo button (editing mode) | Cancel edits, revert to saved |
| save-button-{postId} | Checkmark button (editing mode) | Save changes to server |

## Logging Points

Logger automatically adds `[APP]` prefix. Filter with: `adb logcat | grep "[APP] [PostView]"`

| Log Message | When Emitted |
|-------------|--------------|
| `[PostView] Own post detected: {postId}` | PostView renders a post owned by current user |
| `[PostView] Edit button tapped: {postId}` | User taps pencil button to enter edit mode |
| `[PostView] Entered edit mode: {postId}` | Edit mode activated, fields become editable |
| `[PostView] Title changed: {postId}` | User modifies title text |
| `[PostView] Summary changed: {postId}` | User modifies summary text |
| `[PostView] Body changed: {postId}` | User modifies body text |
| `[PostView] Cancel tapped: {postId}` | User taps cancel button |
| `[PostView] Changes reverted: {postId}` | Fields reverted to saved values |
| `[PostView] Save tapped: {postId}` | User taps save button |
| `[PostView] Saving to server: {postId}` | HTTP request initiated |
| `[PostView] Save succeeded: {postId}` | Server returned success |
| `[PostView] Save failed: {postId} - {error}` | Server returned error |
| `[PostView] Exited edit mode: {postId}` | Edit mode deactivated |

## Test Sequences

### test-edit-button-appears
*Verify pencil button appears for own expanded post*

```
1. restart app
2. expect "[Toolbar] Appeared"
3. wait for posts to load
4. tap first-post (expand it)
5. expect "[PostView] Own post detected: {postId}"
6. verify edit-button-{postId} is visible
```

### test-enter-edit-mode
*Verify tapping pencil enters edit mode*

```
1. restart app
2. wait for posts to load
3. tap first-post (expand it)
4. tap edit-button-{postId}
5. expect "[PostView] Edit button tapped: {postId}"
6. expect "[PostView] Entered edit mode: {postId}"
7. verify cancel-button-{postId} is visible
8. verify save-button-{postId} is visible
```

### test-cancel-edit
*Verify cancel button reverts changes*

```
1. restart app
2. wait for posts to load
3. tap first-post (expand it)
4. tap edit-button-{postId}
5. expect "[PostView] Entered edit mode: {postId}"
6. (modify title field via automation)
7. expect "[PostView] Title changed: {postId}"
8. tap cancel-button-{postId}
9. expect "[PostView] Cancel tapped: {postId}"
10. expect "[PostView] Changes reverted: {postId}"
11. expect "[PostView] Exited edit mode: {postId}"
12. verify edit-button-{postId} is visible (back to non-edit state)
```

### test-save-edit
*Verify save button persists changes to server*

```
1. restart app
2. wait for posts to load
3. tap first-post (expand it)
4. tap edit-button-{postId}
5. expect "[PostView] Entered edit mode: {postId}"
6. (modify title field via automation)
7. expect "[PostView] Title changed: {postId}"
8. tap save-button-{postId}
9. expect "[PostView] Save tapped: {postId}"
10. expect "[PostView] Saving to server: {postId}"
11. expect "[PostView] Save succeeded: {postId}"
12. expect "[PostView] Exited edit mode: {postId}"
13. verify edit-button-{postId} is visible (back to non-edit state)
```

## Running Tests Manually

```bash
# Setup port forwarding (once per session)
adb forward tcp:8081 tcp:8081

# Verify elements are registered
curl http://localhost:8081/test/list-elements

# Expand a post
curl -X POST "http://localhost:8081/test/tap?id=first-post"

# Enter edit mode
curl -X POST "http://localhost:8081/test/tap?id=edit-button-{postId}"

# Cancel edit
curl -X POST "http://localhost:8081/test/tap?id=cancel-button-{postId}"

# Check logs
adb logcat -d | grep "\[PostView\]"

# Restart app to reset state
adb shell am force-stop com.miso.noobtest
adb shell am start -n com.miso.noobtest/.MainActivity
```

## Notes

- Edit button only appears for posts owned by the current user
- Edit button only visible when post is expanded and not already editing
- Cancel reverts ALL fields (title, summary, body) to their saved server values
- Save sends all three fields to the server regardless of which changed
- Post stays expanded after both cancel and save
- Only text editing in this minimal version - no image editing
