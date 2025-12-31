package com.miso.noobtest

import androidx.compose.ui.graphics.Color

/**
 * Centralized app colors matching iOS styling.
 */
object AppColors {
    // Background - black
    val background = Color(0xFF000000)

    // Primary accent - orange/peach (matches iOS button-colour)
    val accent = Color(0xFFFFB280)

    // Accent highlight (darker, for pressed states)
    val accentHighlight = Color(0xFFCC8F66)

    // Text on dark background
    val textPrimary = Color.White
    val textSecondary = Color(0xFFAAAAAA)

    // Text on light/accent background
    val textOnAccent = Color.Black

    // Card/surface colors
    val surface = Color(0xFF1A1A1A)
    val surfaceVariant = Color(0xFF2A2A2A)
}
