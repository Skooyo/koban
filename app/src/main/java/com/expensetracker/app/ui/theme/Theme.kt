package com.expensetracker.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.expensetracker.app.R

/**
 * Money colours. The six notes come from the Malaysian ringgit (RM10 red, RM1 blue, RM20 orange,
 * RM100 purple, RM50 teal, gold foil); dark mode uses brighter "polymer" versions so they hold
 * up on the ink background.
 */
@Immutable
data class MoneyColors(
    val received: Color,
    val review: Color,
    val red: Color,
    val blue: Color,
    val orange: Color,
    val purple: Color,
    val teal: Color,
    val gold: Color,
    val custom: Color,
    val other: Color,
    val uncategorized: Color
)

private val LightMoney = MoneyColors(
    received = Color(0xFF188A4A),
    review = Color(0xFFA85A00),
    red = Color(0xFFE5483B),
    blue = Color(0xFF1F6FE0),
    orange = Color(0xFFF08A1C),
    purple = Color(0xFF7B4FD6),
    teal = Color(0xFF0E9C95),
    gold = Color(0xFFD8A31A),
    custom = Color(0xFF4C5FD5),
    other = Color(0xFF6B7686),
    uncategorized = Color(0xFF6B7686)
)

private val DarkMoney = MoneyColors(
    received = Color(0xFF5EDB8F),
    review = Color(0xFFF0B060),
    red = Color(0xFFFF6B5E),
    blue = Color(0xFF5B9BFF),
    orange = Color(0xFFFFA94D),
    purple = Color(0xFFA98BFF),
    teal = Color(0xFF3CC6C0),
    gold = Color(0xFFF2C94C),
    custom = Color(0xFF8C9EFF),
    other = Color(0xFF8A96A8),
    uncategorized = Color(0xFFA3AEBD)
)

val LocalMoneyColors = staticCompositionLocalOf { LightMoney }

/** Colour for a category id. Custom categories all share one colour, like the indigo they are saved with. */
@Composable
fun categoryColor(categoryId: String?): Color {
    val c = LocalMoneyColors.current
    return when (categoryId) {
        "food" -> c.red
        "transport" -> c.blue
        "shopping" -> c.purple
        "bills" -> c.orange
        "entertainment" -> c.gold
        "health" -> c.teal
        "other" -> c.other
        null -> c.uncategorized
        else -> c.custom
    }
}

private val LightColors = lightColorScheme(
    primary = Color(0xFF1F5FD1),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFDCE6F5),
    onPrimaryContainer = Color(0xFF12305E),
    secondary = Color(0xFF4A5A70),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFDDE3EA),
    onSecondaryContainer = Color(0xFF1B2430),
    tertiary = Color(0xFFA85A00),
    background = Color(0xFFF3F5F4),
    onBackground = Color(0xFF1B2430),
    surface = Color(0xFFF3F5F4),
    onSurface = Color(0xFF1B2430),
    surfaceVariant = Color(0xFFE2E7EA),
    onSurfaceVariant = Color(0xFF586474),
    surfaceContainerLowest = Color.White,
    surfaceContainerLow = Color(0xFFEBEFF0),
    surfaceContainer = Color(0xFFE6EAEC),
    surfaceContainerHigh = Color(0xFFE0E5E8),
    surfaceContainerHighest = Color(0xFFDAE0E4),
    outline = Color(0xFF8C97A5),
    outlineVariant = Color(0xFFD3D9DF)
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF6EA8FF),
    onPrimary = Color(0xFF0A2350),
    primaryContainer = Color(0xFF22406F),
    onPrimaryContainer = Color(0xFFD8E6FF),
    secondary = Color(0xFFB4C0D0),
    onSecondary = Color(0xFF1E2938),
    secondaryContainer = Color(0xFF33415A),
    onSecondaryContainer = Color(0xFFE3EAF5),
    tertiary = Color(0xFFF0B060),
    error = Color(0xFFFF8A80),
    onError = Color(0xFF5C0E14),
    errorContainer = Color(0xFF7A1F2B),
    onErrorContainer = Color(0xFFFFE3E0),
    background = Color(0xFF161D29),
    onBackground = Color(0xFFEEF2F7),
    surface = Color(0xFF161D29),
    onSurface = Color(0xFFEEF2F7),
    surfaceVariant = Color(0xFF263042),
    onSurfaceVariant = Color(0xFFA3AEBD),
    surfaceContainerLowest = Color(0xFF111722),
    surfaceContainerLow = Color(0xFF1B2331),
    surfaceContainer = Color(0xFF1F2836),
    surfaceContainerHigh = Color(0xFF263042),
    surfaceContainerHighest = Color(0xFF2D384B),
    outline = Color(0xFF6B7788),
    outlineVariant = Color(0xFF2C3747)
)

// One variable font. Text sizes use the small optical size; display sizes use the large one.
@OptIn(ExperimentalTextApi::class)
private fun bricolage(weight: Int, opticalSize: Float) = Font(
    R.font.bricolage_grotesque,
    weight = FontWeight(weight),
    variationSettings = FontVariation.Settings(
        FontVariation.weight(weight),
        FontVariation.Setting("opsz", opticalSize)
    )
)

private val TextFamily = FontFamily(
    bricolage(400, 14f),
    bricolage(500, 14f),
    bricolage(600, 14f),
    bricolage(700, 14f)
)

private val DisplayFamily = FontFamily(
    bricolage(500, 96f),
    bricolage(600, 96f),
    bricolage(700, 96f)
)

private val base = Typography()

private fun TextStyle.text() = copy(fontFamily = TextFamily)
private fun TextStyle.display(weight: FontWeight, tracking: Float) =
    copy(fontFamily = DisplayFamily, fontWeight = weight, letterSpacing = tracking.sp)

private val AppTypography = Typography(
    displayLarge = base.displayLarge.display(FontWeight.Bold, -1.5f),
    displayMedium = base.displayMedium.display(FontWeight.Bold, -1f),
    displaySmall = base.displaySmall.display(FontWeight.Bold, -0.5f),
    headlineLarge = base.headlineLarge.display(FontWeight.SemiBold, -0.5f),
    headlineMedium = base.headlineMedium.display(FontWeight.SemiBold, -0.25f),
    headlineSmall = base.headlineSmall.display(FontWeight.SemiBold, 0f),
    titleLarge = base.titleLarge.text().copy(fontWeight = FontWeight.SemiBold),
    titleMedium = base.titleMedium.text().copy(fontWeight = FontWeight.SemiBold, letterSpacing = 0.sp),
    titleSmall = base.titleSmall.text().copy(fontWeight = FontWeight.SemiBold, letterSpacing = 0.sp),
    bodyLarge = base.bodyLarge.text(),
    bodyMedium = base.bodyMedium.text(),
    bodySmall = base.bodySmall.text(),
    labelLarge = base.labelLarge.text(),
    labelMedium = base.labelMedium.text(),
    labelSmall = base.labelSmall.text()
)

@Composable
fun ExpenseTrackerTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    CompositionLocalProvider(LocalMoneyColors provides if (darkTheme) DarkMoney else LightMoney) {
        MaterialTheme(
            colorScheme = if (darkTheme) DarkColors else LightColors,
            typography = AppTypography,
            content = content
        )
    }
}
