package com.example.frontend

import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "bovisense/bluetooth"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connectedAudioDeviceNames" -> result.success(connectedAudioDeviceNames())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Nombres de los dispositivos de audio conectados por Bluetooth clasico
     * (audifonos, parlantes, manos libres). El plugin BLE solo expone
     * conexiones GATT, por eso se consulta aqui el estado de los perfiles.
     */
    private fun connectedAudioDeviceNames(): List<String> {
        if (!hasBluetoothPermission()) return emptyList()
        return try {
            val manager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                ?: return emptyList()
            val adapter = manager.adapter ?: return emptyList()
            if (!adapter.isEnabled) return emptyList()

            val profiles = listOf(BluetoothProfile.A2DP, BluetoothProfile.HEADSET)
            val names = LinkedHashSet<String>()
            for (profile in profiles) {
                // getConnectedDevices ya devuelve solo los dispositivos conectados.
                for (device in manager.getConnectedDevices(profile)) {
                    val name = device.name?.trim().orEmpty()
                    if (name.isNotEmpty()) names.add(name)
                }
            }
            names.toList()
        } catch (_: SecurityException) {
            emptyList()
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun hasBluetoothPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
    }
}
