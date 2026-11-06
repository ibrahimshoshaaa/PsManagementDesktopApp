# PS Management Desktop Offline

نسخة ويندوز مستقلة تعمل بقاعدة Drift/SQLite على الكمبيوتر. في أول تشغيل اكتب اسم المحل وحدد كلمة سر الأدمن. حسابات الكاشير تُضاف من الإعدادات.

- ملف البيانات `ps_app_offline.sqlite` موجود في مجلد `Offline` داخل مجلد بيانات التطبيق للمستخدم على ويندوز.
- تبدأ النسخة بقاعدة مستقلة. بيانات Firebase وملف SQLite للنسخة المتزامنة لا تنتقل تلقائيًا.
- إدارة الجلسات والتربيزات والبوفيه والمخزون والعملاء والشيفتات والتقارير تعمل على بيانات هذا الكمبيوتر. متابعة المحل من الموبايل وطلبات العملاء عبر QR تتطلب النسخة المتزامنة.
- تصدير التقارير يتم محليًا. يستخدم PDF خط Tahoma المثبت على ويندوز.

## بناء نسخة ويندوز

```sh
flutter create . --platforms=windows
flutter pub get
dart run build_runner build
flutter build windows --release
```

يُرفع ملف ويندوز المضغوط إلى Artifacts بعد نجاح GitHub Actions.

## ترخيص العملاء

اعمل الخطوات دي مرة واحدة على جهازك أنت. أداة إصدار الأكواد موجودة في `tools/issue_license.py`.

```powershell
py -m pip install cryptography
py tools/issue_license.py init
```

احفظ نسخة احتياطية من ملف المفتاح الخاص المشفّر الموجود في
`%USERPROFILE%\.ps-desktop-licensing\issuer.pem` ومن كلمة سره. ضيف **المفتاح العام** اللي طبعه أمر
`init` إلى GitHub في **Settings → Secrets and variables → Actions → Variables**
باسم `PS_LICENSE_PUBLIC_KEY`، وبعدها شغّل workflow البناء على فرع
`codex/desktop-offline`. ملف الـ ZIP الناتج هو اللي يتبعت للعميل. البناء من غير المفتاح العام
ينتج نسخة لا تقبل التفعيل. للبناء المحلي مرّر
`--dart-define=PS_LICENSE_PUBLIC_KEY=PUBLIC_KEY_HERE` لأمر `flutter build`.

لما العميل يبعت معرّف الجهاز من شاشة الترخيص، شغّل الأمر ده عندك، واكتب كلمة سر المفتاح، وابعت له الناتج:

```powershell
py tools/issue_license.py issue --device DEVICE_ID --days 7
```

المدة تبدأ من إصدار الكود، سواء كان تجربة أو إيجار. التجديد بنفس الخطوات ومتاح من زر
**الترخيص والتجديد** عند الأدمن. إعادة تثبيت ويندوز أو تغيّر معرّف تثبيت ويندوز قد تتطلب كودًا جديدًا.
الكود بيتحقق منه محليًا، وإلغاء كود صادر قبل نهايته عن بُعد غير متاح في النسخة الأوفلاين.
