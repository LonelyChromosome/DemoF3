package vn.edu.phenikaa.better_phenikaa_schedule

internal object OverviewPager {
    fun panelHeight(hostHeightDp: Int): Int = hostHeightDp.coerceIn(120, 140)

    // Fixed slots: one or two subjects must not expand to fill the entire row.
    fun columns(widthDp: Int): Int = when {
        widthDp >= 540 -> 5
        widthDp >= 300 -> 4
        else -> 3
    }

    fun rows(heightDp: Int): Int = 1

    fun compactSubject(subject: String, slotWidthDp: Int): String {
        if (slotWidthDp >= 100 || subject.length <= 14) return subject
        val words = subject.split(Regex("\\s+")).filterNot {
            it.equals("và", true) || it.equals("cho", true) || it.equals("của", true)
        }
        return words.mapNotNull { it.firstOrNull()?.uppercaseChar() }.joinToString("")
            .ifEmpty { subject }
    }

    fun pageSize(widthDp: Int, heightDp: Int): Int =
        columns(widthDp) * rows(panelHeight(heightDp))

    fun lastPage(itemCount: Int, pageSize: Int): Int =
        if (itemCount == 0) 0 else (itemCount - 1) / pageSize

    fun clamp(page: Int, itemCount: Int, pageSize: Int): Int =
        page.coerceIn(0, lastPage(itemCount, pageSize))

    fun visible(items: List<WidgetClass>, page: Int, pageSize: Int): List<WidgetClass> {
        val first = clamp(page, items.size, pageSize) * pageSize
        return items.drop(first).take(pageSize)
    }
}
