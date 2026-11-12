package app.unscroll.unscroll

import app.unscroll.unscroll.apps.InstalledApps
import app.unscroll.unscroll.capabilities.CapabilityReporter
import app.unscroll.unscroll.permissions.PermissionGateway
import app.unscroll.unscroll.reminders.BudgetReminders
import app.unscroll.unscroll.usage.UsageReader
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val permissions by lazy { PermissionGateway(this) }
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.unscroll/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPlatformReport" -> result.success(CapabilityReporter(permissions).report())
                    "requestPermission" -> {
                        if (pendingPermissionResult != null) {
                            result.success(
                                mapOf("outcome" to "failed", "message" to "A request is already open."),
                            )
                            return@setMethodCallHandler
                        }
                        val outcome = permissions.request(call.argument<String>("permission"))
                        if (outcome != null) result.success(outcome) else pendingPermissionResult = result
                    }
                    "listInstalledApps" -> guarded(result) { InstalledApps(this).list() }
                    "getUsageReport" -> guarded(result) {
                        if (!permissions.hasUsageAccess()) throw SecurityException("no usage access")
                        UsageReader(this).report()
                    }
                    "syncPlan" -> guarded(result) {
                        @Suppress("UNCHECKED_CAST")
                        BudgetReminders.sync(this, call.arguments as? Map<String, Any?> ?: emptyMap())
                        null
                    }
                    "scheduleSessionEnd" -> guarded(result) {
                        BudgetReminders.scheduleSessionEnd(
                            this,
                            call.argument<Number>("atMs")?.toLong() ?: 0L,
                            call.argument<String>("title") ?: "Focus session finished",
                        )
                        null
                    }
                    "cancelSessionEnd" -> guarded(result) {
                        BudgetReminders.cancelSessionEnd(this)
                        null
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** A native failure becomes a channel error the Dart side handles; it never crashes the app. */
    private fun guarded(result: MethodChannel.Result, block: () -> Any?) {
        try {
            result.success(block())
        } catch (e: SecurityException) {
            result.error("not_authorized", e.message, null)
        } catch (e: Exception) {
            result.error("native_failure", e.message, null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PermissionGateway.NOTIFICATION_REQUEST) {
            pendingPermissionResult?.success(this.permissions.outcomeFor(grantResults))
            pendingPermissionResult = null
        }
    }
}
