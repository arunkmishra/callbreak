package com.akm.callbreak_client

import android.app.Application
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val stackTrace = throwable.stackTraceToString()
                Log.e("MainApplication", "Native Crash: $stackTrace")
                
                // Construct a safe JSON string
                val msg = throwable.message?.replace("\"", "\\\"")?.replace("\n", " ") ?: "null"
                val st = stackTrace.replace("\"", "\\\"").replace("\n", "\\n").replace("\t", "\\t")
                
                val payload = """
                    {
                        "platform": "Android-Native",
                        "username": "NativeCrash",
                        "message": "$msg",
                        "stackTrace": "$st"
                    }
                """.trimIndent()
                
                val worker = thread {
                    try {
                        val url = URL("https://callbreak-1.onrender.com/api/logs/frontend")
                        val conn = url.openConnection() as HttpURLConnection
                        conn.requestMethod = "POST"
                        conn.setRequestProperty("Content-Type", "application/json")
                        conn.doOutput = true
                        conn.outputStream.write(payload.toByteArray())
                        conn.responseCode // execute
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
                worker.join(2000) // Block for 2s max to ensure log is sent before process dies
            } catch (e: Exception) {
                e.printStackTrace()
            }
            
            // Allow default crash dialog
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }
}
