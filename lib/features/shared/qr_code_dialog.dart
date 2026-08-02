import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';

/// نفس منطق بناء الروابط بالظبط زي شاشة QR في تطبيق الموبايل (qr_screen.dart)
/// — لازم يفضل مطابق 100% عشان صفحة الطلب (ps-harifa.web.app) تفهم اللينك.
class QrLinkBuilder {
  static String _encodedShopId(String shopId) => base64Url.encode(utf8.encode(shopId)).replaceAll('=', '');

  static String device(String shopId, int deviceId) => 'https://ps-harifa.web.app/?s=${_encodedShopId(shopId)}&d=$deviceId';

  static String table(String shopId, int tableIndex) =>
      'https://ps-harifa.web.app/?s=${_encodedShopId(shopId)}&t=$tableIndex';

  static String drinkTable(String shopId, int drinkTableIndex) =>
      'https://ps-harifa.web.app/?s=${_encodedShopId(shopId)}&dt=$drinkTableIndex';
}

/// دايالوج بيعرض QR للعميل يمسحه ويطلب من موبايله — نفس فكرة QrScreen
/// بالضبط بس كـ dialog بدل شاشة كاملة (أنسب لواجهة الديسكتوب).
void showQrCodeDialog(
  BuildContext context, {
  required String name,
  required String url,
  required Color color,
  required String typeLabel,
  required IconData icon,
  required String subtitle,
}) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24),
                Text('QR - $name', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text('$typeLabel  •  $name', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 30, spreadRadius: 5)],
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                errorStateBuilder: (ctx, err) => const SizedBox(
                  width: 220,
                  height: 220,
                  child: Center(child: Text('خطأ في QR')),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('📱 العميل يمسح الكود للطلب',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.6), textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
