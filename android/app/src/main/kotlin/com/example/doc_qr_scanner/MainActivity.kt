package com.example.doc_qr_scanner

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.doc_qr_scanner/file_manager"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openFolder" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            openFolderWithFile(filePath)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "File path is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openFolderWithFile(filePath: String) {
        val file = File(filePath)
        val folder = file.parentFile ?: File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).absolutePath)
        
        try {
            // Method 1: Use DocumentsContract to open the exact folder containing the file
            val folderUri = getFolderDocumentUri(folder)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(folderUri, DocumentsContract.Document.MIME_TYPE_DIR)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            try {
                // Method 2: Fallback - Use ACTION_GET_CONTENT to browse to folder
                val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "*/*"
                    addCategory(Intent.CATEGORY_OPENABLE)
                    putExtra("android.provider.extra.INITIAL_URI", getFolderDocumentUri(folder))
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (e2: Exception) {
                // Method 3: Final fallback - Open with system file picker at the folder
                try {
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(Uri.fromFile(folder), "resource/folder")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                } catch (e3: Exception) {
                    throw Exception("Cannot open folder: ${e.message}")
                }
            }
        } catch (e: Exception) {
            throw Exception("Cannot open folder: ${e.message}")
        }
    }
    
    private fun getFolderDocumentUri(folder: File): Uri {
        val path = folder.absolutePath
        return when {
            // Handle /storage/emulated/0/Download/OCR → primary:Download/OCR
            path.startsWith("/storage/emulated/0/Download") -> {
                val relativePath = path.substring("/storage/emulated/0".length).trimStart('/')
                Uri.parse("content://com.android.externalstorage.documents/document/primary:${Uri.encode(relativePath)}")
            }
            // Handle /storage/emulated/0/Documents/... → primary:Documents/...
            path.startsWith("/storage/emulated/0/") -> {
                val relativePath = path.substring("/storage/emulated/0/".length)
                Uri.parse("content://com.android.externalstorage.documents/document/primary:${Uri.encode(relativePath)}")
            }
            else -> {
                // Fallback to Downloads
                Uri.parse("content://com.android.externalstorage.documents/document/primary:Download")
            }
        }
    }
    
    private fun openDownloadsFolder() {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(
                Uri.parse("content://com.android.externalstorage.documents/document/primary:Download"),
                DocumentsContract.Document.MIME_TYPE_DIR
            )
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
