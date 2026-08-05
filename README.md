# سجل أحمال الموزعات — المشروع الكامل

هذا المجلد يحتوي على هيكل Flutter كامل لأندرويد والويب، بما في ذلك `android/app`.

## قبل التشغيل

1. انسخ ملف Firebase الخاص بالمشروع إلى:
   `android/app/google-services.json`
2. افتح المجلد الرئيسي في Android Studio.
3. نفّذ:
   ```powershell
   flutter clean
   flutter pub get
   flutter run
   ```

## بناء APK تجريبي

```powershell
flutter build apk --debug
```

المسار:
`build/app/outputs/flutter-apk/app-debug.apk`

## بناء APK إصدار

ملف الإصدار الحالي يستخدم توقيع debug مؤقتًا حتى يتم إنشاء مفتاح التوقيع النهائي. بعد اكتمال الاختبارات:

```powershell
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

المسار:
`build/app/outputs/flutter-apk/app-release.apk`

## تنبيه

إعدادات Firebase وقواعد Firestore يجب نشرها من حساب Firebase الخاص بك. ملف القواعد موجود في:
`lib/firebase/firestore.rules`
