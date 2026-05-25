package com.example.attendance

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

class BunkSafeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateOne(context, appWidgetManager, id)
        }
    }

    private fun updateOne(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.bunksafe_widget)
        val prefs = HomeWidgetPlugin.getData(context)
        val payload = prefs.getString(KEY_PAYLOAD, null)

        // Tap-to-open MainActivity.
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pi = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, pi)

        // Always-shown bits: date + percentage chip + footer.
        if (payload == null) {
            renderEmpty(views)
            appWidgetManager.updateAppWidget(widgetId, views)
            return
        }

        try {
            val json = JSONObject(payload)
            views.setTextViewText(R.id.widget_date, json.optString("date", ""))
            views.setTextViewText(R.id.widget_pct, json.optString("pct", "—"))
            views.setTextViewText(R.id.widget_footer, json.optString("footer", ""))

            val isHoliday = json.optBoolean("isHoliday", false)
            if (isHoliday) {
                views.setViewVisibility(R.id.widget_status, View.VISIBLE)
                views.setTextViewText(
                    R.id.widget_status,
                    "🏖  " + json.optString("holidayLabel", "Holiday"),
                )
                hideAllClasses(views)
                views.setViewVisibility(R.id.class_more, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_status, View.GONE)
                val classes = json.optJSONArray("classes")
                renderClasses(views, classes)
            }
        } catch (_: Exception) {
            renderEmpty(views)
        }
        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun renderEmpty(views: RemoteViews) {
        views.setTextViewText(R.id.widget_date, "")
        views.setTextViewText(R.id.widget_pct, "—")
        views.setTextViewText(R.id.widget_footer, "Open BunkSafe to set up")
        views.setViewVisibility(R.id.widget_status, View.GONE)
        hideAllClasses(views)
        views.setViewVisibility(R.id.class_more, View.GONE)
    }

    private fun renderClasses(views: RemoteViews, classes: org.json.JSONArray?) {
        hideAllClasses(views)
        views.setViewVisibility(R.id.class_more, View.GONE)
        if (classes == null || classes.length() == 0) {
            views.setViewVisibility(R.id.widget_status, View.VISIBLE)
            views.setTextViewText(R.id.widget_status, "No classes today")
            return
        }
        val shown = minOf(classes.length(), CLASS_ROWS.size)
        for (i in 0 until shown) {
            val item = classes.optJSONObject(i) ?: continue
            val subject = item.optString("subject", "")
            val teacher = item.optString("teacher", "")
            val status = item.optString("status", "-")
            val line = if (teacher.isNotBlank()) "$subject  ·  $teacher" else subject
            val row = CLASS_ROWS[i]
            views.setTextViewText(row.textId, line)
            views.setImageViewResource(row.iconId, iconForStatus(status))
            views.setViewVisibility(row.rowId, View.VISIBLE)
        }
        if (classes.length() > CLASS_ROWS.size) {
            views.setTextViewText(
                R.id.class_more,
                "+${classes.length() - CLASS_ROWS.size} more",
            )
            views.setViewVisibility(R.id.class_more, View.VISIBLE)
        }
    }

    private fun iconForStatus(code: String): Int = when (code) {
        "P" -> R.drawable.ic_status_present
        "A" -> R.drawable.ic_status_absent
        "O" -> R.drawable.ic_status_off
        else -> R.drawable.ic_status_unmarked
    }

    private fun hideAllClasses(views: RemoteViews) {
        for (row in CLASS_ROWS) {
            views.setViewVisibility(row.rowId, View.GONE)
        }
    }

    private data class ClassRow(val rowId: Int, val iconId: Int, val textId: Int)

    companion object {
        private const val KEY_PAYLOAD = "widget_payload"
        private val CLASS_ROWS = listOf(
            ClassRow(R.id.class_1, R.id.class_1_icon, R.id.class_1_text),
            ClassRow(R.id.class_2, R.id.class_2_icon, R.id.class_2_text),
            ClassRow(R.id.class_3, R.id.class_3_icon, R.id.class_3_text),
            ClassRow(R.id.class_4, R.id.class_4_icon, R.id.class_4_text),
            ClassRow(R.id.class_5, R.id.class_5_icon, R.id.class_5_text),
        )

        /// Helper that the app uses to force a redraw of every BunkSafe widget
        /// instance currently on the user's home screen.
        @JvmStatic
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, BunkSafeWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val intent = Intent(context, BunkSafeWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }
}
