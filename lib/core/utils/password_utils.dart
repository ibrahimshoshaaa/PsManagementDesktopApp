import 'dart:convert';
import 'package:crypto/crypto.dart';

/// نفس دالة hash_password في بايثون بالظبط:
///   hashlib.sha256(password.encode()).hexdigest()
/// (hex صغير — مش عليها .upper()، عكس الـ HMAC بتاع نظام الترخيص)
String hashPassword(String password) {
  return sha256.convert(utf8.encode(password)).toString();
}
