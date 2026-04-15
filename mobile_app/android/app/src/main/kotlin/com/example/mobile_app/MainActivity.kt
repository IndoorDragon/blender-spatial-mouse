package com.example.mobile_app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {

    private val methodChannelName = "phone_spatial_mouse/ar_method"
    private val eventChannelName = "phone_spatial_mouse/ar_pose_stream"

    private var poseStreamHandler: PoseStreamHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val handler = PoseStreamHandler(applicationContext)
        poseStreamHandler = handler

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventChannelName
        ).setStreamHandler(handler)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName
        ).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "startTracking" -> handler.startTracking(result)
                "stopTracking" -> handler.stopTracking(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        poseStreamHandler?.shutdown()
        super.onDestroy()
    }
}

class PoseStreamHandler(
    context: Context
) : EventChannel.StreamHandler, SensorEventListener {

    private val sensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

    private val gameRotationSensor: Sensor? =
        sensorManager.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)

    private val rotationSensor: Sensor? =
        sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

    private var eventSink: EventChannel.EventSink? = null
    private var isRunning = false

    // Current quaternion
    private var qx = 0.0
    private var qy = 0.0
    private var qz = 0.0
    private var qw = 1.0

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun startTracking(result: MethodChannel.Result) {
        val sensor = gameRotationSensor ?: rotationSensor
        if (sensor == null) {
            result.error(
                "SENSOR_NOT_AVAILABLE",
                "Rotation vector sensor is not available on this device",
                null
            )
            return
        }

        val ok = sensorManager.registerListener(
            this,
            sensor,
            SensorManager.SENSOR_DELAY_GAME
        )

        if (!ok) {
            result.error(
                "SENSOR_START_FAILED",
                "Failed to register sensor listener",
                null
            )
            return
        }

        isRunning = true
        result.success(null)
    }

    fun stopTracking(result: MethodChannel.Result) {
        sensorManager.unregisterListener(this)
        isRunning = false
        result.success(null)
    }

    fun shutdown() {
        sensorManager.unregisterListener(this)
        isRunning = false
        eventSink = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // no-op
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (!isRunning || eventSink == null) return

        if (event.sensor.type != Sensor.TYPE_GAME_ROTATION_VECTOR &&
            event.sensor.type != Sensor.TYPE_ROTATION_VECTOR) {
            return
        }

        val rotationMatrix = FloatArray(9)
        SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)

        val remapped = FloatArray(9)
        SensorManager.remapCoordinateSystem(
            rotationMatrix,
            SensorManager.AXIS_X,
            SensorManager.AXIS_Z,
            remapped
        )

        val quat = FloatArray(4)
        SensorManager.getQuaternionFromVector(quat, event.values)

        // Android returns quaternion as [w, x, y, z]
        var newQw = quat[0].toDouble()
        var newQx = quat[1].toDouble()
        var newQy = quat[2].toDouble()
        var newQz = quat[3].toDouble()

        val mag = sqrt(
            newQx * newQx +
            newQy * newQy +
            newQz * newQz +
            newQw * newQw
        )

        if (mag > 0.0) {
            newQx /= mag
            newQy /= mag
            newQz /= mag
            newQw /= mag
        }

        qx = newQx
        qy = newQy
        qz = newQz
        qw = newQw

        val payload = hashMapOf<String, Any>(
            "tracking" to "normal",
            "px" to 0.0,
            "py" to 0.0,
            "pz" to 0.0,
            "qx" to qx,
            "qy" to qy,
            "qz" to qz,
            "qw" to qw,
            "ar_qx" to qx,
            "ar_qy" to qy,
            "ar_qz" to qz,
            "ar_qw" to qw,
            "timestamp" to (SystemClock.elapsedRealtimeNanos().toDouble() / 1_000_000_000.0)
        )

        eventSink?.success(payload)
    }
}