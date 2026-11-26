package com.aurel.aurel

import android.Manifest
import android.content.ContentUris
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.database.ContentObserver
import android.net.Uri
import android.os.Looper
import java.io.ByteArrayOutputStream
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private companion object {
        const val DEVICE_LIBRARY_CHANNEL = "com.aurel.music/device_library"
        const val AUDIO_PERMISSION_REQUEST = 7401
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val mediaExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var audioChangeObserver: ContentObserver? = null
    private var audioChangeSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.aurel.music/device_library/changes",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(
                arguments: Any?,
                events: EventChannel.EventSink?,
            ) {
                audioChangeSink = events
                if (hasAudioPermission()) registerAudioChangeObserver()
            }

            override fun onCancel(arguments: Any?) {
                audioChangeSink = null
                unregisterAudioChangeObserver()
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_LIBRARY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAudioPermission" -> result.success(hasAudioPermission())
                "requestAudioPermission" -> requestAudioPermission(result)
                "loadAlbumArtwork" -> {
                    val rawUri = call.arguments?.toString().orEmpty()
                    val uri = Uri.parse(rawUri)
                    if (uri.scheme != "content" ||
                        uri.authority != "media" ||
                        !uri.path.orEmpty().startsWith("/external/audio/albumart/")) {
                        result.error(
                            "invalid_artwork_uri",
                            "Only Android MediaStore artwork is supported.",
                            null,
                        )
                    } else {
                        mediaExecutor.execute {
                            val artwork = try {
                                readArtwork(uri)
                            } catch (_: SecurityException) {
                                null
                            } catch (_: Exception) {
                                null
                            }
                            mainHandler.post { result.success(artwork) }
                        }
                    }
                }
                "queryAudioTracks" -> {
                    if (!hasAudioPermission()) {
                        result.error(
                            "audio_permission_denied",
                            "Allow AUREL to access audio before viewing Songs on this device.",
                            null,
                        )
                    } else {
                        mediaExecutor.execute {
                            try {
                                val tracks = queryAudioTracks()
                                mainHandler.post { result.success(tracks) }
                            } catch (error: SecurityException) {
                                mainHandler.post {
                                    result.error(
                                        "media_store_access_denied",
                                        "Android denied access to the local audio library.",
                                        null,
                                    )
                                }
                            } catch (error: Exception) {
                                mainHandler.post {
                                    result.error(
                                        "media_store_query_failed",
                                        error.message ?: "Could not read device audio.",
                                        null,
                                    )
                                }
                            }
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
        checkSelfPermission(audioPermissionName()) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestAudioPermission(result: MethodChannel.Result) {
        if (hasAudioPermission()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error(
                "permission_request_in_progress",
                "An audio permission request is already active.",
                null,
            )
            return
        }
        pendingPermissionResult = result
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
            val callback = pendingPermissionResult
            pendingPermissionResult = null
            callback?.success(
                grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED ||
                    hasAudioPermission(),
            )
        }
    }

    private fun queryAudioTracks(): List<Map<String, Any?>> {
        registerAudioChangeObserver()
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.IS_MUSIC,
            MediaStore.Audio.Media.ALBUM_ID,
        )
        val hasRelativePath = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
        if (hasRelativePath) {
            projection.add(MediaStore.MediaColumns.RELATIVE_PATH)
        } else {
            projection.add(MediaStore.Audio.Media.DATA)
        }

        val selection = if (hasRelativePath) {
            MediaStore.Audio.Media.IS_MUSIC + " != 0 AND " +
                MediaStore.MediaColumns.IS_PENDING + " = 0"
        } else {
            MediaStore.Audio.Media.IS_MUSIC + " != 0"
        }

        val rows = ArrayList<Map<String, Any?>>()
        val cursor = contentResolver.query(
            collection,
            projection.toTypedArray(),
            selection,
            null,
            MediaStore.Audio.Media.TITLE + " COLLATE NOCASE ASC",
        ) ?: return rows

        cursor.use { media ->
            val idIndex = media.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleIndex = media.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistIndex = media.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumIndex = media.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val durationIndex = media.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val albumIdIndex = media.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val pathIndex = if (hasRelativePath) {
                media.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH)
            } else {
                media.getColumnIndex(MediaStore.Audio.Media.DATA)
            }

            while (media.moveToNext()) {
                val sourcePath = if (pathIndex >= 0) {
                    media.getString(pathIndex).orEmpty()
                } else {
                    ""
                }
                // The local Songs tab intentionally excludes Snaptube imports.
                if (sourcePath.contains("snaptube", ignoreCase = true)) continue

                val id = media.getLong(idIndex)
                val title = media.getString(titleIndex).orEmpty().trim()
                if (title.isEmpty()) continue

                val rawArtist = media.getString(artistIndex).orEmpty().trim()
                val artist = if (
                    rawArtist.isEmpty() ||
                    rawArtist.equals("<unknown>", ignoreCase = true)
                ) {
                    "Unknown artist"
                } else {
                    rawArtist
                }
                val rawAlbum = media.getString(albumIndex).orEmpty().trim()
                val album = if (rawAlbum.equals("<unknown>", ignoreCase = true)) "" else rawAlbum
                val uri = ContentUris.withAppendedId(collection, id)

                val albumId = media.getLong(albumIdIndex)
                val artworkUri = if (albumId > 0L) {
                    "content://media/external/audio/albumart/" + albumId
                } else {
                    ""
                }

                rows.add(
                    mapOf(
                        "id" to id.toString(),
                        "uri" to uri.toString(),
                        "title" to title,
                        "artist" to artist,
                        "album" to album,
                        "duration" to media.getLong(durationIndex),
                        "artworkUri" to artworkUri,
                    ),
                )
            }
        }
        return rows
    }

    private fun readArtwork(uri: Uri): ByteArray? {
        val input = contentResolver.openInputStream(uri) ?: return null
        input.use { stream ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            var total = 0
            while (true) {
                val count = stream.read(buffer)
                if (count < 0) break
                total += count
                // Avoid large or unexpected provider payloads in image memory.
                if (total > 5 * 1024 * 1024) return null
                output.write(buffer, 0, count)
            }
            return output.toByteArray().takeIf { it.isNotEmpty() }
        }
    }

    private fun registerAudioChangeObserver() {
        if (audioChangeObserver != null || audioChangeSink == null) return
        val observer = object : ContentObserver(mainHandler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                super.onChange(selfChange, uri)
                audioChangeSink?.success(uri?.toString())
            }
        }
        audioChangeObserver = observer
        contentResolver.registerContentObserver(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            true,
            observer,
        )
    }

    private fun unregisterAudioChangeObserver() {
        val observer = audioChangeObserver ?: return
        contentResolver.unregisterContentObserver(observer)
        audioChangeObserver = null
    }

    override fun onDestroy() {
        unregisterAudioChangeObserver()
        audioChangeSink = null
        if (!mediaExecutor.isShutdown) {
            mediaExecutor.shutdownNow()
        }
        pendingPermissionResult = null
        super.onDestroy()
    }
}
