import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> saveTextFile(String name, String text) async {
  final parts = [text.toJS].toJS;
  final nav = web.window.navigator;
  // iPhone/iPad: Teilen-Menü mit „In Dateien sichern“.
  final file = web.File(parts, name, web.FilePropertyBag(type: 'application/json'));
  final share = web.ShareData(files: [file].toJS, title: name);
  var canShare = false;
  try {
    canShare = nav.canShare(share);
  } catch (_) {
    // Browser ohne Teilen von Dateien.
  }
  if (canShare) {
    try {
      await nav.share(share).toDart;
      return true;
    } catch (e) {
      if (e.toString().contains('AbortError')) return false;
      // Sonst (z. B. nicht erlaubt): weiter mit dem Download.
    }
  }
  final url = web.URL.createObjectURL(web.Blob(parts, web.BlobPropertyBag(type: 'application/json')));
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(a);
  a.click();
  a.remove();
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  return true;
}

Future<String?> pickTextFile() {
  final done = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,application/json,text/plain';
  input.onchange = ((web.Event _) {
    final f = input.files?.item(0);
    if (f == null) {
      if (!done.isCompleted) done.complete(null);
      return;
    }
    f.text().toDart.then(
      (t) {
        if (!done.isCompleted) done.complete(t.toDart);
      },
      onError: (Object _) {
        if (!done.isCompleted) done.complete(null);
      },
    );
  }).toJS;
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!done.isCompleted) done.complete(null);
    }).toJS,
  );
  input.click();
  return done.future;
}

void requestPersistentStorage() {
  try {
    web.window.navigator.storage.persist().toDart.ignore();
  } catch (_) {
    // Ältere Browser ohne Storage-Schnittstelle.
  }
}
