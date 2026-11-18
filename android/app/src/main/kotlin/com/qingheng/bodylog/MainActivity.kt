package com.qingheng.bodylog

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val keepPackage = "com.gotokeep.keep"

    @Suppress("DEPRECATION")
    private fun keepInstalled(): Boolean = try {
        packageManager.getPackageInfo(keepPackage, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.qingheng.bodylog/keep")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isInstalled" -> result.success(keepInstalled())
                    "openAuthorization" -> {
                        val uri = call.argument<String>("url")?.let(Uri::parse)
                        val auth = uri?.encodedPath?.removePrefix("/")?.let(Uri::decode)?.let(Uri::parse)
                        val valid = uri?.scheme == "keep" && uri.host == "webview" &&
                            auth?.scheme == "https" && auth.host == "show.gotokeep.com" &&
                            auth.path == "/login/auth" && auth.userInfo == null &&
                            auth.port == -1 && auth.fragment == null
                        if (!valid || !keepInstalled()) {
                            result.success(false)
                        } else {
                            try {
                                // Target Keep explicitly; never hand the authorization to a browser.
                                startActivity(Intent(Intent.ACTION_VIEW, uri).setPackage(keepPackage))
                                result.success(true)
                            } catch (_: ActivityNotFoundException) {
                                result.success(false)
                            } catch (_: SecurityException) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
