// Kleiner Webserver für die Vorschau der gebauten Web-App (build/web).
//
//   flutter build web
//   dart run tool/serve.dart          # http://localhost:8123
import 'dart:io';

const types = {
  'html': 'text/html; charset=utf-8',
  'js': 'text/javascript; charset=utf-8',
  'mjs': 'text/javascript; charset=utf-8',
  'json': 'application/json; charset=utf-8',
  'css': 'text/css; charset=utf-8',
  'wasm': 'application/wasm',
  'png': 'image/png',
  'svg': 'image/svg+xml',
  'ico': 'image/x-icon',
  'mp3': 'audio/mpeg',
  'ttf': 'font/ttf',
  'otf': 'font/otf',
  'woff2': 'font/woff2',
  'bin': 'application/octet-stream',
  'frag': 'application/octet-stream',
};

Future<void> main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8123;
  final root = Directory('build/web').absolute.path;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Yomicha-Vorschau: http://localhost:$port  ($root)');
  await for (final req in server) {
    var path = Uri.decodeComponent(req.uri.path);
    if (path.endsWith('/')) path += 'index.html';
    final file = File('$root$path');
    final inside = file.absolute.path.startsWith(root);
    if (!inside || !file.existsSync()) {
      req.response
        ..statusCode = HttpStatus.notFound
        ..write('Nicht gefunden: $path');
      await req.response.close();
      continue;
    }
    final ext = path.split('.').last.toLowerCase();
    req.response.headers
      ..set('Content-Type', types[ext] ?? 'application/octet-stream')
      ..set('Cache-Control', 'no-store');
    await req.response.addStream(file.openRead());
    await req.response.close();
  }
}
