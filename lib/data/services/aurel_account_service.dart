import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music_playlist.dart';
import '../models/track.dart';

class CloudLibrarySnapshot {
  const CloudLibrarySnapshot({
    required this.favorites,
    required this.playlists,
    required this.recentlyPlayed,
  });

  final List<Track> favorites;
  final List<MusicPlaylist> playlists;
  final List<Track> recentlyPlayed;
}

/// Firebase-backed identity and cross-install library sync.
///
/// Firebase client configuration is supplied at build time. No private
/// service-account key or OAuth client secret is bundled in the app.
class AurelAccountService {
  AurelAccountService();

  static const _usernameKey = 'aurel.username.v1';

  static const _apiKey = String.fromEnvironment('AUREL_FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('AUREL_FIREBASE_APP_ID');
  static const _projectId = String.fromEnvironment('AUREL_FIREBASE_PROJECT_ID');
  static const _senderId =
      String.fromEnvironment('AUREL_FIREBASE_MESSAGING_SENDER_ID');
  static const _googleServerClientId =
      String.fromEnvironment('AUREL_GOOGLE_SERVER_CLIENT_ID');

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  GoogleSignIn? _googleSignIn;

  bool _firebaseReady = false;
  bool _googleReady = false;
  String? initializationError;
  String userName = 'Music Lover';

  bool get isConfigured => _firebaseReady && _auth != null && _firestore != null;
  bool get isGoogleAvailable => isConfigured && _googleReady;
  User? get currentUser => _auth?.currentUser;
  bool get isSignedIn => currentUser != null;

  List<String> get linkedProviders => currentUser?.providerData
          .map((provider) => provider.providerId)
          .toSet()
          .toList(growable: false) ??
      const [];

  Future<void> initialize() async {
    userName = await _preferences.getString(_usernameKey) ?? 'Music Lover';

    if (_apiKey.isEmpty ||
        _appId.isEmpty ||
        _projectId.isEmpty ||
        _senderId.isEmpty) {
      initializationError =
          'Cloud accounts are not configured for this AUREL build yet.';
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: _apiKey,
            appId: _appId,
            messagingSenderId: _senderId,
            projectId: _projectId,
          ),
        );
      }

      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _firebaseReady = true;

      if (_googleServerClientId.isNotEmpty) {
        _googleSignIn = GoogleSignIn.instance;
        await _googleSignIn!.initialize(
          serverClientId: _googleServerClientId,
        );
        _googleReady = true;
      }

      if (currentUser != null) {
        userName = await loadUserName();
      }
      initializationError = null;
    } on FirebaseException catch (error) {
      initializationError = error.message ?? error.code;
      _firebaseReady = false;
      _googleReady = false;
    } catch (error) {
      initializationError = error.toString();
      _firebaseReady = false;
      _googleReady = false;
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    _requireConfigured();
    if (!isGoogleAvailable || _googleSignIn == null) {
      throw StateError(
        'Google Sign-In is not configured for this AUREL build.',
      );
    }

    final googleUser = await _googleSignIn!.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google did not return an identity token. Check the OAuth client configuration.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth!.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _requireConfigured();
    return _auth!.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> createEmailAccount({
    required String email,
    required String password,
    required String username,
  }) async {
    _requireConfigured();
    final result = await _auth!.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await setUserName(username);
    await result.user?.sendEmailVerification();
    return result;
  }

  Future<void> linkEmail({
    required String email,
    required String password,
  }) async {
    _requireSignedIn();
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    await currentUser!.linkWithCredential(credential);
  }

  Future<void> linkGoogle() async {
    _requireSignedIn();
    if (!isGoogleAvailable || _googleSignIn == null) {
      throw StateError('Google linking is not configured for this build.');
    }

    final googleUser = await _googleSignIn!.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google did not return an identity token.');
    }

    await currentUser!.linkWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  Future<void> sendPasswordReset(String email) async {
    _requireConfigured();
    await _auth!.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendVerificationEmail() async {
    _requireSignedIn();
    final user = currentUser!;
    if (user.emailVerified) return;
    await user.sendEmailVerification();
  }

  Future<void> setUserName(String value) async {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2 || normalized.length > 24) {
      throw const FormatException(
        'Choose a username between 2 and 24 characters.',
      );
    }

    userName = normalized;
    await _preferences.setString(_usernameKey, normalized);

    final user = currentUser;
    final firestore = _firestore;
    if (user != null && firestore != null) {
      await user.updateDisplayName(normalized);
      await firestore.collection('users').doc(user.uid).set(
        {
          'username': normalized,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  Future<String> loadUserName() async {
    final user = currentUser;
    final firestore = _firestore;
    if (user != null && firestore != null) {
      try {
        final profile = await firestore.collection('users').doc(user.uid).get();
        final cloudName = profile.data()?['username']?.toString().trim();
        if (cloudName != null && cloudName.isNotEmpty) {
          userName = cloudName;
          await _preferences.setString(_usernameKey, cloudName);
          return userName;
        }
      } catch (error) {
        debugPrint('AUREL username restore failed: $error');
      }

      final displayName = user.displayName?.trim();
      if ((userName == 'Music Lover' || userName.isEmpty) &&
          displayName != null &&
          displayName.isNotEmpty) {
        userName = displayName;
        await _preferences.setString(_usernameKey, displayName);
      }
    }
    return userName;
  }

  Future<CloudLibrarySnapshot?> loadCloudLibrary() async {
    final user = currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return null;

    final library = firestore
        .collection('users')
        .doc(user.uid)
        .collection('library');

    final results = await Future.wait([
      library.doc('favorites').collection('items').get(),
      library.doc('recentlyPlayed').collection('items').get(),
      library.doc('playlists').collection('items').get(),
    ]);

    List<Track> readTracks(QuerySnapshot<Map<String, dynamic>> snapshot) {
      final ordered = snapshot.docs.toList()
        ..sort((a, b) =>
            (a.data()['sortOrder'] as num? ?? 0)
                .compareTo(b.data()['sortOrder'] as num? ?? 0));
      return ordered.map((document) {
        final raw = document.data()['track'];
        return raw is Map<String, dynamic> ? Track.fromJson(raw) : null;
      }).whereType<Track>().toList(growable: false);
    }

    final playlistDocs = results[2].docs
      ..sort((a, b) =>
          (a.data()['sortOrder'] as num? ?? 0)
              .compareTo(b.data()['sortOrder'] as num? ?? 0));
    final playlists = <MusicPlaylist>[];
    for (final document in playlistDocs) {
      final raw = document.data()['playlist'];
      if (raw is Map<String, dynamic>) {
        playlists.add(MusicPlaylist.fromJson(raw));
      }
    }

    return CloudLibrarySnapshot(
      favorites: readTracks(results[0]),
      recentlyPlayed: readTracks(results[1]),
      playlists: playlists,
    );
  }

  Future<void> saveCloudLibrary({
    required List<Track> favorites,
    required List<MusicPlaylist> playlists,
    required List<Track> recentlyPlayed,
  }) async {
    final user = currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    final library = firestore
        .collection('users')
        .doc(user.uid)
        .collection('library');

    final remoteFavorites = favorites
        .where((track) => !track.isDeviceTrack && track.streamUrl.isNotEmpty)
        .toList(growable: false);
    final remoteHistory = recentlyPlayed
        .where((track) => !track.isDeviceTrack && track.streamUrl.isNotEmpty)
        .take(100)
        .toList(growable: false);

    final remotePlaylists = playlists.map((playlist) {
      final tracks = playlist.tracks
          .where((track) => !track.isDeviceTrack && track.streamUrl.isNotEmpty)
          .map(_trackForCloudModel)
          .toList(growable: false);
      return MusicPlaylist(
        id: playlist.id,
        name: playlist.name,
        tracks: tracks,
      );
    }).toList(growable: false);

    await _replaceTrackCollection(
      library.doc('favorites').collection('items'),
      remoteFavorites,
    );
    await _replaceTrackCollection(
      library.doc('recentlyPlayed').collection('items'),
      remoteHistory,
    );
    await _replacePlaylistCollection(
      library.doc('playlists').collection('items'),
      remotePlaylists,
    );

    await firestore.collection('users').doc(user.uid).set(
      {'lastLibrarySyncAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> _replaceTrackCollection(
    CollectionReference<Map<String, dynamic>> collection,
    List<Track> tracks,
  ) async {
    final existing = await collection.get();
    final ids = tracks.map((track) => _documentId(track.id)).toSet();
    final stale = existing.docs.where((document) => !ids.contains(document.id));

    for (final chunk in _chunks(stale.toList(), 400)) {
      final batch = _firestore!.batch();
      for (final document in chunk) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }

    for (var start = 0; start < tracks.length; start += 400) {
      final end = (start + 400).clamp(0, tracks.length).toInt();
      final batch = _firestore!.batch();
      for (var index = start; index < end; index++) {
        final track = tracks[index];
        final reference = collection.doc(_documentId(track.id));
        batch.set(
          reference,
          {
            'track': _trackForCloud(track),
            'sortOrder': index,
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  Future<void> _replacePlaylistCollection(
    CollectionReference<Map<String, dynamic>> collection,
    List<MusicPlaylist> playlists,
  ) async {
    final existing = await collection.get();
    final ids = playlists.map((playlist) => _documentId(playlist.id)).toSet();
    final stale = existing.docs.where((document) => !ids.contains(document.id));

    for (final chunk in _chunks(stale.toList(), 400)) {
      final batch = _firestore!.batch();
      for (final document in chunk) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }

    for (var start = 0; start < playlists.length; start += 400) {
      final end = (start + 400).clamp(0, playlists.length).toInt();
      final batch = _firestore!.batch();
      for (var index = start; index < end; index++) {
        final playlist = playlists[index];
        batch.set(
          collection.doc(_documentId(playlist.id)),
          {
            'playlist': playlist.toJson(),
            'sortOrder': index,
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  Track _trackForCloudModel(Track track) => Track.fromJson({
        ...track.toJson(),
        'localPath': null,
        'isDownloaded': false,
        'isDeviceTrack': false,
      });

  Map<String, dynamic> _trackForCloud(Track track) {
    final json = track.toJson();
    // File paths are specific to the current installation. They cannot be
    // restored after uninstall and must never be mistaken for cloud files.
    json['localPath'] = null;
    json['isDownloaded'] = false;
    json['isDeviceTrack'] = false;
    return json;
  }

  String _documentId(String id) =>
      base64Url.encode(utf8.encode(id)).replaceAll('=', '');

  List<List<T>> _chunks<T>(List<T> values, int size) {
    final result = <List<T>>[];
    for (var start = 0; start < values.length; start += size) {
      final end = (start + size).clamp(0, values.length).toInt();
      result.add(values.sublist(start, end));
    }
    return result;
  }

  Future<void> signOut() async {
    if (_googleReady) {
      await _googleSignIn?.signOut();
    }
    await _auth?.signOut();
  }

  void _requireConfigured() {
    if (!isConfigured) {
      throw StateError(
        initializationError ??
            'Cloud accounts are not configured for this AUREL build.',
      );
    }
  }

  void _requireSignedIn() {
    if (!isConfigured || currentUser == null) {
      throw StateError('Sign in to your AUREL account first.');
    }
  }
}
