package com.aurel.aurel

import android.Manifest
import android.content.ContentUris
import android.content.pm.PackageManager
import android.os.Build
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private companion object {
        const val DEVICE_LIBRARY_CHANNEL = "com.aurel.music/device_library"
        const val AUDIO_PERMISSION_REQUEST = 7401
    }

    private var pendingAudioPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_LIBRARY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAudioPermission" -> result.success(hasAudioPermission())
                "requestAudioPermission" -> requestAudioPermission(result)
                "queryAudioTracks" -> {
                    if (!hasAudioPermission()) {
                        result.error(
                            "audio_permission_denied",
                            "AUREL needs audio access to show music on this device.",
                            null,
                        )
                    } else {
                        try {
                            result.success(queryAudioTracks())
                        } catch (error: SecurityException) {
                            result.error(
                                "media_store_access_denied",
                                "Android did not allow access to the audio library.",
                                null,
                            )
                        } catch (error: Exception) {
                            result.error(
                                "media_store_query_failed",
                                error.message ?: "Could not read device audio.",
                                null,
                            )
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun audioPermissionName(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }

    private fun hasAudioPermission(): Boolean =
        checkSelfPermission(audioPermissionName()) == PackageManager.PERMISSION_GRANTED

    private fun requestAudioPermission(result: MethodChannel.Result) {
        if (hasAudioPermission()) {
            result.success(true)
            return
        }
        if (pendingAudioPermissionResult != null) {
            result.error(
                "permission_request_in_progress",
                "An audio permission request is already active.",
                null,
            )
            return
        }
        pendingAudioPermissionResult = result
        requestPermissions(
            arrayOf(audioPermissionName()),
            AUDIO_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == AUDIO_PERMISSION_REQUEST) {
            val callback = pendingAudioPermissionResult
            pendingAudioPermissionResult = null
            callback?.success(
                grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED ||
                    hasAudioPermission(),
            )
        }
    }

    private fun queryAudioTracks(): List<Map<String, Any?>> {
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val columns = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.IS_MUSIC,
            MediaStore.Audio.Media.DATA,
        )
        val hasRelativePath = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
        if (hasRelativePath) {
            columns.add(MediaStore.MediaColumns.RELATIVE_PATH)
        }

        val selection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND " +
                "${MediaStore.MediaColumns.IS_PENDING} = 0"
        } else {
            "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        }

        val result = ArrayList<Map<String, Any?>>()
        val cursor = contentResolver.query(
            collection,
            columns.toTypedArray(),
            selection,
            null,
            "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC",
        ) ?: return result

        cursor.use { rows ->
            val idIndex = rows.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleIndex = rows.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistIndex = rows.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumIndex = rows.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val durationIndex = rows.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val dataIndex = rows.getColumnIndex(MediaStore.Audio.Media.DATA)
            val relativePathIndex = if (hasRelativePath) {
                rows.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH)
            } else {
                -1
            }

            while (rows.moveToNext()) {
                val relativePath = if (relativePathIndex >= 0) {
                    rows.getString(relativePathIndex).orEmpty()
                } else {
                    ""
                }
                val dataPath = if (dataIndex >= 0) {
                    rows.getString(dataIndex).orEmpty()
                } else {
                    ""
                }
                // AUREL's local library deliberately excludes Snaptube imports.
                val indexedPath = "$relativePath/$dataPath"
                    .replace('\\', '/')
                    .lowercase()
                if (indexedPath.contains("snaptube")) continue

                val id = rows.getLong(idIndex)
                val title = rows.getString(titleIndex).orEmpty().trim()
                if (title.isEmpty()) continue

                val artist = rows.getString(artistIndex).orEmpty().trim()
                    .takeUnless { it.isEmpty() || it == MediaStore.UNKNOWN_STRING }
                    ?: "Unknown artist"
                val album = rows.getString(albumIndex).orEmpty().trim()
                    .takeUnless { it == MediaStore.UNKNOWN_STRING }
                    ?: ""
                val uri = ContentUris.withAppendedId(collection, id)

                result.add(
                    mapOf(
                        "id" to id.toString(),
                        "uri" to uri.toString(),
                        "title" to title,
                        "artist" to artist,
                        "album" to album,
                        "duration" to rows.getLong(durationIndex),
                    ),
                )
            }
        }
        return result
    }
}
