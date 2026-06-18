/// Real web localStorage implementation.
/// This file is only imported when targeting the web platform.
library web_storage;

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:hive/hive.dart';
import 'hive_storage.dart';

/// Web implementation of [HiveStorage] using browser localStorage.
class WebStorage implements HiveStorage {
  const WebStorage._();
  static const WebStorage instance = WebStorage._();

  static const _accessTokenKey = 'sg_access_token';
  static const _refreshTokenKey = 'sg_refresh_token';
  static const _pendingQrTokenKey = 'sg_pending_qr';
  static const _userNameKey = 'sg_user_name';
  static const _userEmailKey = 'sg_user_email';
  static const _userProfilePhotoKey = 'sg_user_photo';

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    html.window.localStorage[_accessTokenKey] = accessToken;
    html.window.localStorage[_refreshTokenKey] = refreshToken;
  }

  @override
  String? getAccessToken() {
    final v = html.window.localStorage[_accessTokenKey];
    return (v == null || v.isEmpty) ? null : v;
  }

  @override
  String? getRefreshToken() {
    final v = html.window.localStorage[_refreshTokenKey];
    return (v == null || v.isEmpty) ? null : v;
  }

  @override
  Future<void> clearTokens() async {
    html.window.localStorage.remove(_accessTokenKey);
    html.window.localStorage.remove(_refreshTokenKey);
    html.window.localStorage.remove(_userNameKey);
    html.window.localStorage.remove(_userEmailKey);
    html.window.localStorage.remove(_userProfilePhotoKey);
  }

  @override
  Future<void> saveProfile({
    required String name,
    String? email,
    String? profilePhoto,
  }) async {
    html.window.localStorage[_userNameKey] = name;
    if (email != null) {
      html.window.localStorage[_userEmailKey] = email;
    } else {
      html.window.localStorage.remove(_userEmailKey);
    }
    if (profilePhoto != null) {
      html.window.localStorage[_userProfilePhotoKey] = profilePhoto;
    } else {
      html.window.localStorage.remove(_userProfilePhotoKey);
    }
  }

  @override
  Map<String, String?> getProfile() {
    return {
      'name': html.window.localStorage[_userNameKey],
      'email': html.window.localStorage[_userEmailKey],
      'profilePhoto': html.window.localStorage[_userProfilePhotoKey],
    };
  }

  @override
  Future<void> savePendingQrToken(String token) async {
    html.window.localStorage[_pendingQrTokenKey] = token;
  }

  @override
  String? getPendingQrToken() {
    final v = html.window.localStorage[_pendingQrTokenKey];
    return (v == null || v.isEmpty) ? null : v;
  }

  @override
  Future<void> clearPendingQrToken() async {
    html.window.localStorage.remove(_pendingQrTokenKey);
  }

  @override
  Box<dynamic> get galleryBox =>
      throw UnsupportedError('galleryBox not available on web');

  @override
  Box<dynamic> get folderBox =>
      throw UnsupportedError('folderBox not available on web');

  @override
  Box<dynamic> get mediaBox =>
      throw UnsupportedError('mediaBox not available on web');
}
