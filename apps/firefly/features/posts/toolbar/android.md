# toolbar Android implementation
*Jetpack Compose floating toolbar with three explorer buttons*

## Overview

Implements a sleek, rounded lozenge toolbar at the bottom of the screen using Jetpack Compose. The toolbar floats above content with a strong shadow. It contains three Material icons (chat bubble, search, people) arranged horizontally. Each button switches to a different explorer view.

## Files to Modify

1. **MainActivity.kt** - Add explorer switching logic and toolbar
2. **Toolbar.kt** - NEW FILE - Create toolbar component
3. **build.gradle.kts** - Add material-icons-extended dependency

## Dependencies

Add to `app/build.gradle.kts`:

```kotlin
implementation("androidx.compose.material:material-icons-extended")
```

Also ensure gradle has enough memory in `gradle.properties`:

```
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
```

## Implementation

### Toolbar.kt

Create at: `app/src/main/kotlin/com/miso/noobtest/Toolbar.kt`

**Key implementation details:**

1. **State Management**: Use `rememberUpdatedState` for all callback parameters to prevent stale closures in UI automation and click handlers
2. **Button Highlighting**: Only apply background when `isActive` is true, using conditional `Modifier.then()`
3. **No Ripple Effect**: Use `indication = null` on clickable to prevent visual artifacts on inactive buttons
4. **UI Automation**: Register elements with `RegisterUIElement()` for remote testing

```kotlin
package com.miso.noobtest

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.People
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.Icon
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp

enum class ToolbarExplorer {
    MAKE_POST, SEARCH, USERS
}

@Composable
fun Toolbar(
    currentExplorer: ToolbarExplorer,
    onExplorerChange: (ToolbarExplorer) -> Unit,
    onResetMakePost: () -> Unit,
    onResetSearch: () -> Unit,
    onResetUsers: () -> Unit,
    showPostsBadge: Boolean = false,
    showSearchBadge: Boolean = false,
    showUsersBadge: Boolean = false
) {
    // CRITICAL: Use rememberUpdatedState to keep values current in callbacks
    // Without this, closures capture stale values and button highlighting breaks
    val currentExplorerState by rememberUpdatedState(currentExplorer)
    val onExplorerChangeState by rememberUpdatedState(onExplorerChange)
    val onResetMakePostState by rememberUpdatedState(onResetMakePost)
    val onResetSearchState by rememberUpdatedState(onResetSearch)
    val onResetUsersState by rememberUpdatedState(onResetUsers)

    // Log toolbar appearance
    LaunchedEffect(Unit) {
        Logger.log("[Toolbar] Appeared")
    }

    // Register UI automation elements
    RegisterUIElement("toolbar-makepost") {
        if (currentExplorerState == ToolbarExplorer.MAKE_POST) {
            Logger.log("[Toolbar] Reset makePost view")
            onResetMakePostState()
        } else {
            Logger.log("[Toolbar] Explorer changed to: makePost")
            onExplorerChangeState(ToolbarExplorer.MAKE_POST)
        }
    }

    RegisterUIElement("toolbar-search") {
        if (currentExplorerState == ToolbarExplorer.SEARCH) {
            Logger.log("[Toolbar] Reset search view")
            onResetSearchState()
        } else {
            Logger.log("[Toolbar] Explorer changed to: search")
            onExplorerChangeState(ToolbarExplorer.SEARCH)
        }
    }

    RegisterUIElement("toolbar-users") {
        if (currentExplorerState == ToolbarExplorer.USERS) {
            Logger.log("[Toolbar] Reset users view")
            onResetUsersState()
        } else {
            Logger.log("[Toolbar] Explorer changed to: users")
            onExplorerChangeState(ToolbarExplorer.USERS)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp)
            .padding(bottom = 34.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .shadow(
                    elevation = 12.dp,
                    shape = RoundedCornerShape(12.dp),
                    ambientColor = Color.Black.copy(alpha = 0.4f),
                    spotColor = Color.Black.copy(alpha = 0.4f)
                )
                .clip(RoundedCornerShape(12.dp))
                .background(AppColors.accent)
                .padding(horizontal = 66.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            ToolbarButton(
                icon = Icons.Outlined.ChatBubbleOutline,
                isActive = currentExplorerState == ToolbarExplorer.MAKE_POST,
                showBadge = showPostsBadge,
                onClick = {
                    if (currentExplorerState == ToolbarExplorer.MAKE_POST) {
                        Logger.log("[Toolbar] Reset makePost view")
                        onResetMakePostState()
                    } else {
                        Logger.log("[Toolbar] Explorer changed to: makePost")
                        onExplorerChangeState(ToolbarExplorer.MAKE_POST)
                    }
                }
            )

            ToolbarButton(
                icon = Icons.Outlined.Search,
                isActive = currentExplorerState == ToolbarExplorer.SEARCH,
                showBadge = showSearchBadge,
                onClick = {
                    if (currentExplorerState == ToolbarExplorer.SEARCH) {
                        Logger.log("[Toolbar] Reset search view")
                        onResetSearchState()
                    } else {
                        Logger.log("[Toolbar] Explorer changed to: search")
                        onExplorerChangeState(ToolbarExplorer.SEARCH)
                    }
                }
            )

            ToolbarButton(
                icon = Icons.Outlined.People,
                isActive = currentExplorerState == ToolbarExplorer.USERS,
                showBadge = showUsersBadge,
                onClick = {
                    if (currentExplorerState == ToolbarExplorer.USERS) {
                        Logger.log("[Toolbar] Reset users view")
                        onResetUsersState()
                    } else {
                        Logger.log("[Toolbar] Explorer changed to: users")
                        onExplorerChangeState(ToolbarExplorer.USERS)
                    }
                }
            )
        }
    }
}

@Composable
fun ToolbarButton(
    icon: ImageVector,
    isActive: Boolean,
    showBadge: Boolean = false,
    onClick: () -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }

    Box(
        modifier = Modifier
            .size(35.dp)
            .then(
                // CRITICAL: Only apply background when active
                // Using .then() prevents visual artifacts on inactive buttons
                if (isActive) {
                    Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(AppColors.accentHighlight)
                } else {
                    Modifier
                }
            )
            .clickable(
                interactionSource = interactionSource,
                indication = null,  // CRITICAL: Removes ripple effect that causes visual artifacts
                onClick = onClick
            ),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color.Black,
            modifier = Modifier.size(20.dp)
        )

        if (showBadge) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = 2.dp, y = (-2).dp)
                    .size(10.dp)
                    .clip(CircleShape)
                    .background(Color.Red)
            )
        }
    }
}
```

### MainActivity.kt Changes

In the `FireflyApp()` composable, replace the simple `PostsView()` call with toolbar integration:

```kotlin
else -> {
    var currentExplorer by remember { mutableStateOf(ToolbarExplorer.MAKE_POST) }
    var makePostResetKey by remember { mutableStateOf(0) }
    var searchResetKey by remember { mutableStateOf(0) }
    var usersResetKey by remember { mutableStateOf(0) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.background)
    ) {
        // Explorer content - use key() to force recreation on reset
        when (currentExplorer) {
            ToolbarExplorer.MAKE_POST -> {
                key(makePostResetKey) { PostsView() }
            }
            ToolbarExplorer.SEARCH -> {
                key(searchResetKey) {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("Search Explorer", color = AppColors.textPrimary)
                    }
                }
            }
            ToolbarExplorer.USERS -> {
                key(usersResetKey) {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("Users Explorer", color = AppColors.textPrimary)
                    }
                }
            }
        }

        // Floating toolbar at bottom
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
            Toolbar(
                currentExplorer = currentExplorer,
                onExplorerChange = { currentExplorer = it },
                onResetMakePost = { makePostResetKey++ },
                onResetSearch = { searchResetKey++ },
                onResetUsers = { usersResetKey++ }
            )
        }
    }
}
```

## Visual Specifications

| Property | Value |
|----------|-------|
| Corner radius | 12.dp |
| Shadow elevation | 12.dp |
| Shadow color | Black @ 40% opacity |
| Background | AppColors.accent (#FFB280) |
| Active highlight | AppColors.accentHighlight (#CC8F66) |
| Horizontal padding | 8.dp (outer), 66.dp (inner) |
| Vertical padding | 16.dp |
| Bottom offset | 34.dp |
| Button size | 35x35.dp |
| Button corner radius | 6.dp |
| Icon size | 20.dp |
| Icon color | Black |
| Badge size | 10.dp red circle |

## UI Automation Elements

| Element ID | Description |
|------------|-------------|
| `toolbar-makepost` | Posts button (chat bubble icon) |
| `toolbar-search` | Search button (magnifying glass icon) |
| `toolbar-users` | Users button (people icon) |

## Logging Points

All logs prefixed with `[APP]` by Logger automatically:

| Log Message | When Emitted |
|-------------|--------------|
| `[Toolbar] Appeared` | Toolbar renders |
| `[Toolbar] Explorer changed to: makePost` | Switch to posts |
| `[Toolbar] Explorer changed to: search` | Switch to search |
| `[Toolbar] Explorer changed to: users` | Switch to users |
| `[Toolbar] Reset makePost view` | Double-tap posts |
| `[Toolbar] Reset search view` | Double-tap search |
| `[Toolbar] Reset users view` | Double-tap users |

## Key Learnings / Gotchas

1. **Stale Closures**: When registering UI automation callbacks or passing lambdas to child composables, the captured parameter values become stale. Use `rememberUpdatedState()` to always get the current value.

2. **Button Highlighting**: Using `Color.Transparent` for inactive buttons can still show visual artifacts. Use conditional `Modifier.then()` to only apply background when active.

3. **Ripple Effects**: The default `clickable()` adds ripple indication that can appear as a dim square. Use `indication = null` to disable.

4. **Memory**: The material-icons-extended library is large and may require increasing Gradle JVM memory to 2048MB.
