import 'package:firebase_core/firebase_core.dart';

class AppConfig {
  static const ministryName = 'وزارة الكهرباء والطاقة المتجددة';
  static const companyName = 'شركة جنوب القاهرة لتوزيع الكهرباء';
  static const controlName = 'تحكم ٢٦';
  static const departmentName = 'وسائل النقل';
  static const reportTitle = 'تقرير تموين سيارة';

  static const driverSignature = 'توقيع السائق';
  static const transportHeadSignature = 'توقيع رئيس وسائل النقل';
  static const generalManagerSignature = 'توقيع المدير العام';

  static const firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyCM4pEKqvSyBwJrKdocayd0bJJ8oJnRo6o',
  );
  static const firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:294540598095:android:b4a49c12622deb7a43033a',
  );
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'vehicle-fuel-costs',
  );
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '294540598095',
  );
  static const firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'vehicle-fuel-costs.firebasestorage.app',
  );

  static bool get firebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseStorageBucket.isNotEmpty;

  static FirebaseOptions get firebaseOptions => FirebaseOptions(
        apiKey: firebaseApiKey,
        appId: firebaseAppId,
        messagingSenderId: firebaseMessagingSenderId,
        projectId: firebaseProjectId,
        storageBucket: firebaseStorageBucket,
      );
}
