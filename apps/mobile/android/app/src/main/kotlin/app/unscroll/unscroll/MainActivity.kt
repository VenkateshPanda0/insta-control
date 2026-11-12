package app.unscroll.unscroll

import app.unscroll.unscroll.capabilities.CapabilityReporter
import app.unscroll.unscroll.permissions.PermissionGateway
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
                    else -> result.notImplemented()
                }
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
