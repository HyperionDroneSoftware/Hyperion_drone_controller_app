package kg.edu.alatoo.alatoo_drone

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "kg.edu.alatoo.alatoo_drone/network"
    private var connectivity: ConnectivityManager? = null
    private var callback: ConnectivityManager.NetworkCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bindToWifi" -> bindToWifi(result)
                    "unbind" -> {
                        unbind()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun bindToWifi(result: MethodChannel.Result) {
        val manager = connectivity
        if (manager == null) {
            result.success(false)
            return
        }

        unbind()
        // Drone access points have no internet, so do not request that capability.
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()
        var replied = false
        val networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                val bound = manager.bindProcessToNetwork(network)
                if (!replied) {
                    replied = true
                    runOnUiThread { result.success(bound) }
                }
            }

            override fun onUnavailable() {
                if (!replied) {
                    replied = true
                    callback = null
                    try {
                        manager.unregisterNetworkCallback(this)
                    } catch (_: IllegalArgumentException) {
                        // Android already removed the failed request.
                    }
                    runOnUiThread { result.success(false) }
                }
            }
        }

        callback = networkCallback
        try {
            manager.requestNetwork(request, networkCallback, 8000)
        } catch (_: SecurityException) {
            callback = null
            result.success(false)
        }
    }

    private fun unbind() {
        val manager = connectivity ?: return
        manager.bindProcessToNetwork(null)
        callback?.let {
            try {
                manager.unregisterNetworkCallback(it)
            } catch (_: IllegalArgumentException) {
                // Already unregistered.
            }
        }
        callback = null
    }

    override fun onDestroy() {
        unbind()
        super.onDestroy()
    }
}
