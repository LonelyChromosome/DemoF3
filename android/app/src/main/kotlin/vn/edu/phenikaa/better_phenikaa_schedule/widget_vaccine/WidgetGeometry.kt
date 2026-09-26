package vn.edu.phenikaa.better_phenikaa_schedule

/** Host dimensions are paired by orientation; max width and min height are landscape. */
internal object WidgetGeometry {
    data class Size(val width: Int, val height: Int)

    fun legacySize(
        minWidth: Int, maxWidth: Int, minHeight: Int, maxHeight: Int,
        landscape: Boolean, defaultWidth: Int, defaultHeight: Int,
    ): Size {
        val narrow = minWidth.takeIf { it > 0 } ?: defaultWidth
        val wide = maxWidth.takeIf { it > 0 } ?: narrow
        val short = minHeight.takeIf { it > 0 } ?: defaultHeight
        val tall = maxHeight.takeIf { it > 0 } ?: short
        return if (landscape) Size(maxOf(narrow, wide), minOf(short, tall))
            else Size(minOf(narrow, wide), maxOf(short, tall))
    }

    data class Overview(
        val panelHeight: Int,
        val headerHeight: Int,
        val footerHeight: Int,
        val cardHeight: Int,
        val compact: Boolean,
        val topPadding: Int,
        val bottomPadding: Int,
    )

    fun overview(height: Int): Overview {
        // The reference geometry remains byte-for-byte equivalent through 156dp.
        val panel = height.coerceAtLeast(104)
        val reference = panel.coerceAtMost(156)
        val compact = reference < 120
        val header = if (compact) 32 else if (reference >= 140) 42 else 36
        val footer = if (compact) 16 else if (reference >= 140) 24 else 20
        val basePadding = if (compact) 4 else 10
        val extra = panel - reference
        // Fill a taller host without stretching cards, circles or the timeline.
        // Keep the card/track group together and center its reference geometry.
        val top = (if (compact) 2 else 6) + extra / 2
        val bottom = (if (compact) 2 else 4) + extra - extra / 2
        return Overview(panel, header, footer,
            reference - basePadding - header - footer - 5,
            compact, top, bottom)
    }
}
