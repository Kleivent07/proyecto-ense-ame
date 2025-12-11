package com.example.my_app

import android.app.*
import android.content.Intent
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.os.Binder
import android.os.Build
import android.os.Environment
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File

class ScreenRecordingService : Service() {
    
    companion object {
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "screen_recording_channel"
        private const val ACTION_STOP_RECORDING = "STOP_RECORDING"
    }
    
    private var mediaRecorder: MediaRecorder? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var mediaProjection: MediaProjection? = null
    private var currentFilePath: String? = null
    
    inner class ScreenRecordingBinder : Binder() {
        fun getService(): ScreenRecordingService = this@ScreenRecordingService
    }
    
    private val binder = ScreenRecordingBinder()
    
    override fun onBind(intent: Intent?): IBinder = binder
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_RECORDING -> {
                stopRecording()
                stopSelf()
            }
            else -> {
                startForeground(NOTIFICATION_ID, createNotification())
            }
        }
        return START_NOT_STICKY
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Grabación de Pantalla",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notificación para grabación de pantalla en progreso"
                setSound(null, null)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val stopIntent = Intent(this, ScreenRecordingService::class.java).apply {
            action = ACTION_STOP_RECORDING
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("EnseñameApp")
            .setContentText("🔴 Grabando pantalla...")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .addAction(
                android.R.drawable.ic_media_pause,
                "Detener",
                stopPendingIntent
            )
            .build()
    }
    
    fun startRecording(
        mediaProjection: MediaProjection,
        fileName: String = "recording"
    ): String? {
        try {
            this.mediaProjection = mediaProjection
            currentFilePath = getRecordingFilePath(fileName)
            
            mediaRecorder = MediaRecorder().apply {
                setVideoSource(MediaRecorder.VideoSource.SURFACE)
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setVideoEncoder(MediaRecorder.VideoEncoder.H264)
                setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)
                setVideoEncodingBitRate(512 * 1000)
                setVideoFrameRate(30)
                setVideoSize(1280, 720)
                setOutputFile(currentFilePath)
                prepare()
            }
            
            virtualDisplay = mediaProjection.createVirtualDisplay(
                "ScreenRecording",
                1280, 720, 1,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                mediaRecorder?.surface,
                null, null
            )
            
            mediaRecorder?.start()
            return currentFilePath
            
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
    
    fun stopRecording(): String? {
        try {
            mediaRecorder?.stop()
            mediaRecorder?.reset()
            virtualDisplay?.release()
            mediaProjection?.stop()
            
            stopForeground(STOP_FOREGROUND_REMOVE)
            return currentFilePath
            
        } catch (e: Exception) {
            e.printStackTrace()
            return currentFilePath
        }
    }
    
    private fun getRecordingFilePath(fileName: String): String {
        val moviesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
        val appDir = File(moviesDir, "EnseñameApp")
        if (!appDir.exists()) {
            appDir.mkdirs()
        }
        return File(appDir, "${fileName}_${System.currentTimeMillis()}.mp4").absolutePath
    }
}