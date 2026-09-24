package vn.edu.phenikaa.better_phenikaa_schedule

internal object OverviewPager {
    // The mockup has five cards across at tablet width. A phone shows two
    // columns in two rows when its widget is tall enough, without dead space.
    fun columns(widthDp: Int): Int = ((widthDp - 24) / 110).coerceIn(1, 5)

    fun rows(heightDp: Int): Int = if (heightDp >= 258) 2 else 1

    fun pageSize(widthDp: Int, heightDp: Int): Int =
        columns(widthDp) * rows(heightDp)

    fun lastPage(itemCount: Int, pageSize: Int): Int =
        if (itemCount == 0) 0 else (itemCount - 1) / pageSize

    fun clamp(page: Int, itemCount: Int, pageSize: Int): Int =
        page.coerceIn(0, lastPage(itemCount, pageSize))

    fun visible(items: List<WidgetClass>, page: Int, pageSize: Int): List<WidgetClass> {
        val first = clamp(page, items.size, pageSize) * pageSize
        return items.drop(first).take(pageSize)
    }
}
