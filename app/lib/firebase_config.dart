/// Firebase ayarları (gizli değildir; güvenlik Firestore kurallarıyla sağlanır, bkz. ../firestore.rules ve ../FIREBASE.md).
/// Boş bırakılırsa puan ve yorumlar yalnızca bu cihazda saklanır (deneme modu).
const String firebaseProjeId =
    String.fromEnvironment('FB_PROJE', defaultValue: '');
const String firebaseApiAnahtari =
    String.fromEnvironment('FB_ANAHTAR', defaultValue: '');
