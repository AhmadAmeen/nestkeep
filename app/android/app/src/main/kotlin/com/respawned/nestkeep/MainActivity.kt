package com.respawned.nestkeep

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Add to calendar": fires the system insert-event intent. The
        // user's calendar app opens with the event prefilled and THEY
        // press save. No calendar permission is requested or needed:
        // this app never reads or writes the calendar itself.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nestkeep/calendar")
            .setMethodCallHandler { call, result ->
                if (call.method == "insertEvent") {
                    val intent = Intent(Intent.ACTION_INSERT).apply {
                        data = CalendarContract.Events.CONTENT_URI
                        putExtra(
                            CalendarContract.Events.TITLE,
                            call.argument<String>("title") ?: ""
                        )
                        putExtra(
                            CalendarContract.Events.DESCRIPTION,
                            call.argument<String>("description") ?: ""
                        )
                        putExtra(
                            CalendarContract.EXTRA_EVENT_BEGIN_TIME,
                            call.argument<Long>("beginMillis") ?: 0L
                        )
                        putExtra(
                            CalendarContract.EXTRA_EVENT_END_TIME,
                            call.argument<Long>("endMillis") ?: 0L
                        )
                        putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, true)
                    }
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
