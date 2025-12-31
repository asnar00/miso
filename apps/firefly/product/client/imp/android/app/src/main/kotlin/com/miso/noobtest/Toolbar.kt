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
import androidx.compose.material3.Text
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
    // Use rememberUpdatedState to keep the current explorer value up-to-date in callbacks
    val currentExplorerState by rememberUpdatedState(currentExplorer)
    val onExplorerChangeState by rememberUpdatedState(onExplorerChange)
    val onResetMakePostState by rememberUpdatedState(onResetMakePost)
    val onResetSearchState by rememberUpdatedState(onResetSearch)
    val onResetUsersState by rememberUpdatedState(onResetUsers)

    // Observe tunables for reactivity
    val tunablesVersion = TunableConstants.version.value
    val buttonColor = TunableConstants.buttonColor()
    val buttonHighlightColor = TunableConstants.buttonHighlightColor()
    val cornerRoundness = TunableConstants.getDouble("corner-roundness", 1.0).toFloat()

    // Log toolbar appearance
    LaunchedEffect(Unit) {
        Logger.log("[Toolbar] Appeared")
    }

    // Register UI automation elements with updated state
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
                    shape = RoundedCornerShape((12 * cornerRoundness).dp),
                    ambientColor = Color.Black.copy(alpha = 0.4f),
                    spotColor = Color.Black.copy(alpha = 0.4f)
                )
                .clip(RoundedCornerShape((12 * cornerRoundness).dp))
                .background(buttonColor)
                .padding(horizontal = 66.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Make Post button
            ToolbarButton(
                icon = Icons.Outlined.ChatBubbleOutline,
                isActive = currentExplorerState == ToolbarExplorer.MAKE_POST,
                showBadge = showPostsBadge,
                highlightColor = buttonHighlightColor,
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

            // Search button
            ToolbarButton(
                icon = Icons.Outlined.Search,
                isActive = currentExplorerState == ToolbarExplorer.SEARCH,
                showBadge = showSearchBadge,
                highlightColor = buttonHighlightColor,
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

            // Users button
            ToolbarButton(
                icon = Icons.Outlined.People,
                isActive = currentExplorerState == ToolbarExplorer.USERS,
                showBadge = showUsersBadge,
                highlightColor = buttonHighlightColor,
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
    highlightColor: Color = AppColors.accentHighlight,
    onClick: () -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }

    Box(
        modifier = Modifier
            .size(35.dp)
            .then(
                if (isActive) {
                    Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(highlightColor)
                } else {
                    Modifier
                }
            )
            .clickable(
                interactionSource = interactionSource,
                indication = null,
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

        // Badge indicator
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
