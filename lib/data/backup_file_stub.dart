// Außerhalb des Browsers (Tests) gibt es keine Dateien zum Teilen.
Future<bool> saveTextFile(String name, String text) async => false;

Future<String?> pickTextFile() async => null;

void requestPersistentStorage() {}

/// Name des Geräts für die Sicherung (z. B. „ipad“).
String geraetName() => 'geraet';
