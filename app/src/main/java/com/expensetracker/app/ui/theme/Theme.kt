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

/** Colours taken from the Malaysian ringgit notes. Each spending category gets one note. */
object Ringgit {
    val Rm1Blue = Color(0xFF2F62A8)
    val Rm5Green = Color(0xFF2E8B57)
    val Rm10Red = Color(0xFFC9423A)
    val Rm20Orange = Color(0xFFE0872F)
    val Rm50Teal = Color(0xFF23898F)
    val Rm100Purple = Color(0xFF7051AE)
    val GoldFoil = Color(0xFFC49A2C)
    val Indigo = Color(0xFF5C6BC0)
    val Slate = Color(0xFF7A8696)
}

/** Colour for a category id. Custom categories all share the indigo they are saved with. */
fun categoryColor(categoryId: String?): Color = when (categoryId) {
    "food" -> Ringgit.Rm10Red
    "transport" -> Ringgit.Rm1Blue
    "shopping" -> Ringgit.Rm100Purple
    "bills" -> Ringgit.Rm20Orange
    "entertainment" -> Ringgit.GoldFoil
    "health" -> Ringgit.Rm50Teal
    null, "other" -> Ringgit.Slate
    else -> Ringgit.Indigo
}

@Immutable
data class MoneyColors(val received: Color, val review: Color)

private val LightMoney = MoneyColors(received = Color(0xFF1F7A47), review = Color(0xFFA85A00))
private val DarkMoney = MoneyColors(received = Color(0xFF7FCF9C), review = Color(0xFFF0B060))

val LocalMoneyColors = staticCompositionLocalOf { LightMoney }

private val LightColors = lightColorScheme(
    primary = Ringgit.Rm1Blue,
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
    primary = Color(0xFF8FB2EA),
    onPrimary = Color(0xFF0E2A55),
    primaryContainer = Color(0xFF23406E),
    onPrimaryContainer = Color(0xFFD8E4F8),
    secondary = Color(0xFFB4C0D0),
    onSecondary = Color(0xFF1E2938),
    secondaryContainer = Color(0xFF2E3A4C),
    onSecondaryContainer = Color(0xFFDDE5EF),
    tertiary = Color(0xFFF0B060),
    background = Color(0xFF1A2230),
    onBackground = Color(0xFFE8EDF3),
    surface = Color(0xFF1A2230),
    onSurface = Color(0xFFE8EDF3),
    surfaceVariant = Color(0xFF2A3546),
    onSurfaceVariant = Color(0xFF9DA9B9),
    surfaceContainerLowest = Color(0xFF151C28),
    surfaceContainerLow = Color(0xFF202A3A),
    surfaceContainer = Color(0xFF243042),
    surfaceContainerHigh = Color(0xFF2A3649),
    surfaceContainerHighest = Color(0xFF313E52),
    outline = Color(0xFF6B7788),
    outlineVariant = Color(0xFF323E50)
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
