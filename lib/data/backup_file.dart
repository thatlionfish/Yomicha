import 'backup_file_stub.dart' if (dart.library.js_interop) 'backup_file_web.dart' as impl;

/// Bietet einen Text als Datei an: auf iPhone und iPad über „Teilen“
/// (z. B. „In Dateien sichern“), sonst als Download. `false`, wenn ich
/// abgebrochen habe. Muss direkt beim Antippen aufgerufen werden.
Future<bool> saveTextFile(String name, String text) => impl.saveTextFile(name, text);

/// Lässt mich eine Datei auswählen und gibt ihren Text zurück.
Future<String?> pickTextFile() => impl.pickTextFile();

/// Bittet den Browser, den Speicher der App nicht von selbst zu leeren.
void requestPersistentStorage() => impl.requestPersistentStorage();
