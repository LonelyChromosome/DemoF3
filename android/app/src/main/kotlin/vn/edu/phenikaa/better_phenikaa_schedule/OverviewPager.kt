package vn.edu.phenikaa.better_phenikaa_schedule

internal object OverviewPager {
    // 40dp header + 22dp status + 30dp navigation + 12dp outer padding.
    // Each compact row takes 60dp plus 4dp spacing.
    fun pageSize(heightDp: Int): Int = ((heightDp - 104) / 64).coerceIn(1, 5)

    fun lastPage(itemCount: Int, pageSize: Int): Int =
        if (itemCount == 0) 0 else (itemCount - 1) / pageSize

    fun clamp(page: Int, itemCount: Int, pageSize: Int): Int =
        page.coerceIn(0, lastPage(itemCount, pageSize))

    fun visible(items: List<WidgetClass>, page: Int, pageSize: Int): List<WidgetClass> {
        val first = clamp(page, items.size, pageSize) * pageSize
        return items.drop(first).take(pageSize)
    }
}
