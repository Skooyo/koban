package com.expensetracker.app.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import com.expensetracker.app.R

enum class MonFace { IDLE, WORRY, HAPPY }

/** Mon, the gold coin mascot. Height is 1.1 times the width. */
@Composable
fun Mon(face: MonFace, size: Dp, modifier: Modifier = Modifier, contentDescription: String? = null) {
    val drawable = when (face) {
        MonFace.IDLE -> R.drawable.mon_idle
        MonFace.WORRY -> R.drawable.mon_worry
        MonFace.HAPPY -> R.drawable.mon_happy
    }
    Image(
        painter = painterResource(drawable),
        contentDescription = contentDescription,
        modifier = modifier.size(width = size, height = size * 1.1f)
    )
}
