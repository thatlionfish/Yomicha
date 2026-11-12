// Erzeugt Kumachan als kleine Teemeisterin (SVG-Einzelbilder in assets/kuma/)
// und die Übersicht lib/widgets/kuma_poses.g.dart.
//
// Kumachan stammt aus LearnwithLeoni (gehäkelte Bärin): Körper, Kopf und
// Farben sind von dort übernommen, damit sie in beiden Apps gleich aussieht.
// Neu in Yomicha: Teeschale mit Matcha, Dampf und eine Teeladen-Schürze.
//
//   dart run tool/gen_kuma.dart
import 'dart:io';
import 'dart:math';

const ink = '#685A4E';
const mauve = '#8E7486';
const mauveDark = '#6F5869';
const mauveLight = '#A38D9C';
const paw = '#F1DCD6';
const collar = '#EFD6E2';
const heartPink = '#E7A9B9';
const nose = '#5B4A3E';
const button = '#FBF8F1';
const wood = '#D7CAB0';
const lemon = '#DCD494';
const sand = '#E3D8C2';
const vanilla = '#F0EADA';
const matcha = '#B9BF6E';

String n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

String limb(String d, {String fill = mauve}) =>
    '<path d="$d" fill="none" stroke-width="19"/>\n'
    '<path d="$d" fill="none" stroke="$fill" stroke-width="15"/>';

String pawAt(num x, num y, {num r = 8}) => '<circle cx="${n(x)}" cy="${n(y)}" r="${n(r)}" fill="$paw"/>';

String rotate(num deg, num cx, num cy, String body) =>
    deg == 0 ? body : '<g transform="rotate(${n(deg)} ${n(cx)} ${n(cy)})">\n$body\n</g>';

String shift(num dx, num dy, String body) =>
    dx == 0 && dy == 0 ? body : '<g transform="translate(${n(dx)} ${n(dy)})">\n$body\n</g>';

/// Kleine Maschen als Andeutung der Häkelarbeit.
String stitches(Random r, {required num cx, required num cy, required num rx, required num ry, int count = 14}) {
  final b = StringBuffer();
  for (var i = 0; i < count; i++) {
    final a = r.nextDouble() * 2 * pi;
    final d = sqrt(r.nextDouble());
    final x = cx + cos(a) * rx * d * 0.85, y = cy + sin(a) * ry * d * 0.85;
    b.writeln(
      '<path d="M${n(x - 1.6)},${n(y - 1)} L${n(x)},${n(y + 1)} L${n(x + 1.6)},${n(y - 1)}" '
      'fill="none" stroke="$mauveDark" stroke-width="0.8" opacity="0.45"/>',
    );
  }
  return b.toString();
}

// --- Körperteile (wie in LearnwithLeoni) --------------------------------

const shadow = '<ellipse cx="100" cy="290" rx="48" ry="5" fill="$wood" stroke="none" opacity="0.55"/>';

const legs = '''
<path d="M78,186 C73,220 69,254 67,277 C66,289 85,291 87,280 C89,256 92,222 97,190 Z" fill="$mauve"/>
<path d="M122,186 C127,220 131,254 133,277 C134,289 115,291 113,280 C111,256 108,222 103,190 Z" fill="$mauve"/>
<path d="M68,282 C72,287 82,288 86,283" fill="none" stroke="$paw" stroke-width="3"/>
<path d="M114,283 C118,288 128,287 132,282" fill="none" stroke="$paw" stroke-width="3"/>''';

const body = '''
<path d="M74,118 C66,140 64,175 74,195 C86,212 114,212 126,195 C136,175 134,140 126,118 C116,108 84,108 74,118 Z" fill="$mauve"/>''';

const collarPart = '''
<path d="M82,111 C94,119 106,119 118,111 C119,117 112,123 100,123 C88,123 81,117 82,111 Z" fill="$collar"/>
<path d="M88,117 L90,121 M96,119 L97,123 M104,119 L103,123 M112,117 L110,121" fill="none" stroke-width="0.9" opacity="0.5"/>''';

const ears = '''
<circle cx="68" cy="46" r="13" fill="$mauve"/>
<circle cx="132" cy="46" r="13" fill="$mauve"/>
<circle cx="69" cy="47" r="6.5" fill="$mauveDark" stroke="none" opacity="0.55"/>
<circle cx="131" cy="47" r="6.5" fill="$mauveDark" stroke="none" opacity="0.55"/>''';

String buttonEye(num x, num y) => '''
<circle cx="${n(x)}" cy="${n(y)}" r="7.2" fill="$button" stroke-width="1.6"/>
<circle cx="${n(x - 2)}" cy="${n(y - 2)}" r="1" fill="$ink" stroke="none"/>
<circle cx="${n(x + 2)}" cy="${n(y - 2)}" r="1" fill="$ink" stroke="none"/>
<circle cx="${n(x - 2)}" cy="${n(y + 2)}" r="1" fill="$ink" stroke="none"/>
<circle cx="${n(x + 2)}" cy="${n(y + 2)}" r="1" fill="$ink" stroke="none"/>
<path d="M${n(x - 2)},${n(y - 2)} L${n(x + 2)},${n(y + 2)} M${n(x + 2)},${n(y - 2)} L${n(x - 2)},${n(y + 2)}" fill="none" stroke="$ink" stroke-width="0.7" opacity="0.7"/>''';

String head({bool happy = false}) => '''
$ears
<circle cx="100" cy="72" r="34" fill="$mauve"/>
${stitches(Random(3), cx: 100, cy: 66, rx: 30, ry: 26, count: 10)}
<ellipse cx="100" cy="85" rx="15.5" ry="12.5" fill="$mauveLight"/>
<ellipse cx="100" cy="80.5" rx="7.2" ry="5.6" fill="$nose" stroke="$nose"/>
<path d="M100,86 L100,89.5" fill="none" stroke-width="1.4"/>
${happy ? '<path d="M93.5,89 C97,95 103,95 106.5,89 Z" fill="#C97F6E" stroke-width="1.4"/>' : '<path d="M95,89.5 C98,92.5 102,92.5 105,89.5" fill="none" stroke-width="1.4"/>'}
${buttonEye(84, 65)}
${buttonEye(116, 65)}''';

// --- Neu in Yomicha: Teemeisterin ----------------------------------------

/// Teeladen-Schürze (前掛け) in Vanilla mit einem Teeblatt in Lemon Grass.
const apron = '''
<path d="M76,164 C84,166 116,166 124,164 C127,178 126,192 122,201 C110,207 90,207 78,201 C74,192 73,178 76,164 Z" fill="$vanilla" stroke-width="1.6"/>
<path d="M76,164 C70,163 66,160 64,156 M124,164 C130,163 134,160 136,156" fill="none" stroke="$sand" stroke-width="3"/>
<path d="M78,168 C90,170 110,170 122,168" fill="none" stroke-width="0.9" opacity="0.5"/>
<path d="M100,176 C93,181 93,190 100,195 C107,190 107,181 100,176 Z" fill="$lemon" stroke-width="1.3"/>
<path d="M100,178 L100,194" fill="none" stroke-width="0.9" opacity="0.7"/>''';

/// Teeschale (茶碗) mit Matcha, gehalten vor der Brust.
const chawan = '''
<path d="M81,146 C81,162 90,168 100,168 C110,168 119,162 119,146 Z" fill="$sand" stroke-width="1.8"/>
<path d="M84,155 C94,158 106,158 116,155" fill="none" stroke="$wood" stroke-width="2.2"/>
<ellipse cx="100" cy="146" rx="19" ry="4.2" fill="$matcha" stroke-width="1.6"/>
<path d="M93,146.5 C97,145 103,145 107,146.5" fill="none" stroke="$lemon" stroke-width="1.2"/>
<path d="M94,168 L95,171 L105,171 L106,168" fill="$sand" stroke-width="1.4"/>''';

/// Dampf über der Schale – zwei Bilder für ein leichtes Aufsteigen.
String steam(int step) {
  final dy = step == 0 ? 0 : -5;
  final op = step == 0 ? 0.55 : 0.35;
  return shift(0, dy, '''
<path d="M93,138 C89,132 97,128 93,121" fill="none" stroke="$wood" stroke-width="1.8" opacity="${n(op)}"/>
<path d="M101,136 C97,129 105,125 101,117" fill="none" stroke="$wood" stroke-width="1.8" opacity="${n(op + 0.1)}"/>
<path d="M109,138 C105,132 113,128 109,121" fill="none" stroke="$wood" stroke-width="1.8" opacity="${n(op)}"/>''');
}

/// Teeschale verschoben und skaliert (Mitte der Schale: 100,157).
String chawanAt(num x, num y, {num s = 1}) =>
    '<g transform="translate(${n(x)} ${n(y)}) scale(${n(s)}) translate(-100 -157)">\n$chawan\n</g>';

/// Teebesen (茶筅) aus Bambus; Griff oben bei (0,0), Borsten nach unten.
const chasen = '''
<path d="M0,0 L0,14" fill="none" stroke="$wood" stroke-width="4.2"/>
<path d="M0,0 L0,14" fill="none" stroke-width="0.9" opacity="0.5"/>
<path d="M-1.5,14 C-6,17 -7,21 -6,24 M0,14 L0,25 M1.5,14 C6,17 7,21 6,24 M-0.8,14 C-3,18 -3.5,22 -3,25 M0.8,14 C3,18 3.5,22 3,25" fill="none" stroke="$wood" stroke-width="1.4"/>''';

/// Schaum beim Schlagen des Matcha.
String froth(int step) => [
  for (final (x, y, r) in step == 0
      ? const [(90.0, 147.0, 1.6), (99.0, 145.5, 1.3), (95.0, 144.5, 1.0)]
      : const [(93.0, 146.0, 1.4), (102.0, 147.0, 1.6), (97.0, 144.5, 1.1)])
    '<circle cx="${n(x)}" cy="${n(y)}" r="${n(r)}" fill="$lemon" stroke-width="0.8"/>',
].join('\n');

String sparkle(num x, num y, {num r = 1}) =>
    '<path d="M${n(x)},${n(y - 7 * r)} L${n(x + 2.2 * r)},${n(y - 2.2 * r)} L${n(x + 7 * r)},${n(y)} '
    'L${n(x + 2.2 * r)},${n(y + 2.2 * r)} L${n(x)},${n(y + 7 * r)} L${n(x - 2.2 * r)},${n(y + 2.2 * r)} '
    'L${n(x - 7 * r)},${n(y)} L${n(x - 2.2 * r)},${n(y - 2.2 * r)} Z" fill="$lemon" stroke-width="1.2"/>';

/// Zufrieden geschlossene Augen (Lider über den Knöpfen) und rosa Wangen.
const contentEyes = '''
<circle cx="84" cy="65" r="8.6" fill="$mauve" stroke="none"/>
<circle cx="116" cy="65" r="8.6" fill="$mauve" stroke="none"/>
<path d="M78,66 C80,60 88,60 90,66 M110,66 C112,60 120,60 122,66" fill="none" stroke-width="2.2"/>
<ellipse cx="76" cy="80" rx="5" ry="3" fill="$heartPink" stroke="none" opacity="0.6"/>
<ellipse cx="124" cy="80" rx="5" ry="3" fill="$heartPink" stroke="none" opacity="0.6"/>''';

/// Gedankenpunkte für „Nachdenken“.
String thinkDots(int step) => [
  for (final (i, (x, y, r)) in const [(136.0, 40.0, 2.4), (145.0, 30.0, 3.2), (156.0, 18.0, 4.2)].indexed)
    if (i < step) '<circle cx="${n(x)}" cy="${n(y)}" r="${n(r)}" fill="$vanilla" stroke-width="1.4"/>',
].join('\n');

/// Ein Bild der Teemeisterin: immer mit Schürze.
///
/// [arms] liegen über der Schürze, [front] über dem Kopf (z. B. eine Pfote am Kinn).
String figure({
  String arms = '',
  String? headPart,
  num bodyRot = 0,
  num bodyDy = 0,
  num headRot = 0,
  num headDy = 0,
  String front = '',
  String extras = '',
  num shadowScale = 1,
}) {
  final inner = [
    legs,
    body,
    stitches(Random(7), cx: 100, cy: 165, rx: 28, ry: 40),
    '<path d="M88,98 C87,106 87,114 86,121 C94,125 106,125 114,121 C113,114 113,106 112,98 Z" fill="$mauve"/>',
    collarPart,
    apron,
    arms,
    rotate(headRot, 100, 112, shift(0, 6 + headDy, headPart ?? head(happy: true))),
    front,
  ].join('\n');
  final shadowSvg = shadowScale == 1
      ? shadow
      : '<ellipse cx="100" cy="290" rx="${n(48 * shadowScale)}" ry="5" fill="$wood" stroke="none" opacity="0.45"/>';
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 300" width="200" height="300">\n'
      '<!-- Kumachan, die kleine Teemeisterin – erzeugt von tool/gen_kuma.dart -->\n'
      '<g stroke="$ink" stroke-width="2" stroke-linejoin="round" stroke-linecap="round">\n'
      '$shadowSvg\n'
      '${rotate(bodyRot, 100, 286, shift(0, bodyDy, inner))}\n'
      '$extras\n</g>\n</svg>\n';
}

/// Kumachan hält die Teeschale mit beiden Pfoten und bietet sie an.
String teaFigure({required int step, num headRot = 0}) => figure(
  arms: [
    limb('M80,126 C70,138 72,152 82,158'),
    limb('M120,126 C130,138 128,152 118,158'),
    chawan,
    pawAt(82, 157, r: 7),
    pawAt(118, 157, r: 7),
    steam(step),
  ].join('\n'),
  headRot: headRot,
);

// Arme: Schulter links (80,126), rechts (120,126).
String armLeftOut() => '${limb('M80,126 C64,131 50,139 39,146')}\n${pawAt(36, 148)}';
String armLeftUp() => '${limb('M80,126 C66,116 58,100 54,84')}\n${pawAt(53, 78)}';
String armRightUp() => '${limb('M120,126 C134,116 142,100 146,84')}\n${pawAt(147, 78)}';

/// Pfoten vor der Schürze gefaltet (für die Verbeugung).
String foldedPaws() => [
  limb('M80,126 C72,146 82,166 95,170'),
  limb('M120,126 C128,146 118,166 105,170'),
  pawAt(95, 169, r: 7),
  pawAt(105, 169, r: 7),
].join('\n');

class Pose {
  const Pose(this.name, this.title, this.frames);
  final String name;
  final String title;
  final List<(String, int)> frames;
}

final poses = <Pose>[
  Pose('tea', 'Tee anbieten', [
    (teaFigure(step: 0, headRot: -3), 900),
    (teaFigure(step: 1, headRot: 2), 900),
  ]),
  // Verbeugung (お辞儀): der Kopf senkt sich, die Pfoten liegen gefaltet auf der Schürze.
  Pose('bow', 'Begrüßen mit Verbeugung', [
    (figure(arms: foldedPaws()), 900),
    (figure(arms: foldedPaws(), headDy: 7, bodyDy: 3), 300),
    (figure(arms: foldedPaws(), headDy: 13, bodyDy: 5, headPart: head()), 900),
    (figure(arms: foldedPaws(), headDy: 7, bodyDy: 3), 300),
  ]),
  // Matcha schlagen: links die Schale, rechts der Teebesen, der hin und her geht.
  Pose('whisk', 'Tee aufgießen', [
    for (final (dx, step) in const [(-4, 0), (4, 1), (-4, 0), (4, 1)])
      (
        figure(
          arms: [
            limb('M80,126 C68,140 70,154 80,160'),
            chawanAt(96, 159),
            pawAt(80, 159, r: 7),
            froth(step),
            limb('M120,126 C134,134 130,130 ${n(110 + dx)},125'),
            shift(103 + dx, 123, rotate(dx * 2, 0, 0, chasen)),
            pawAt(103 + dx, 123, r: 7),
          ].join('\n'),
          headRot: dx > 0 ? 3 : -2,
        ),
        280,
      ),
  ]),
  // Daumen hoch: rechte Pfote oben, mit kleinem Daumen.
  Pose('thumbs', 'Daumen hoch', [
    for (final (deg, ms) in const [(0, 700), (-8, 260), (0, 260), (-8, 260)])
      (
        figure(
          arms: [
            armLeftOut(),
            rotate(deg, 120, 126, '${limb('M120,126 C136,120 146,106 150,92')}\n'
                '${pawAt(151, 88)}\n'
                '<ellipse cx="148" cy="77" rx="4" ry="6" fill="$paw"/>'),
          ].join('\n'),
          headRot: -4,
          extras: deg == 0 ? sparkle(170, 70, r: 0.6) : '',
        ),
        ms,
      ),
  ]),
  // Jubeln: beide Arme hoch, ein kleiner Hüpfer.
  Pose('cheer', 'Jubeln', [
    (figure(arms: '${armLeftUp()}\n${armRightUp()}'), 260),
    (
      figure(
        arms: '${rotate(-8, 80, 126, armLeftUp())}\n${rotate(8, 120, 126, armRightUp())}',
        bodyDy: -14,
        shadowScale: 0.75,
        extras: '${sparkle(36, 54, r: 0.8)}\n${sparkle(166, 46, r: 0.65)}',
      ),
      260,
    ),
  ]),
  // Nachdenken: Pfote am Kinn, Kopf zur Seite, Gedankenpunkte.
  Pose('think', 'Nachdenken', [
    for (final step in [1, 2, 3, 3])
      (
        figure(
          arms: [
            limb('M80,126 C72,146 82,166 95,170'),
            pawAt(95, 169, r: 7),
            limb('M120,126 C134,122 132,108 116,103'),
          ].join('\n'),
          headPart: head(),
          headRot: 8,
          front: pawAt(114, 103, r: 7.5),
          extras: thinkDots(step),
        ),
        step == 3 ? 1000 : 450,
      ),
  ]),
  // Sonntag: die Schale an der Schnauze, Augen zufrieden zu, Dampf.
  Pose('sip', 'Teetrinken am Sonntag', [
    for (final step in [0, 1])
      (
        figure(
          arms: [limb('M80,126 C70,120 72,108 84,104'), limb('M120,126 C130,120 128,108 116,104')].join('\n'),
          headPart: '${head()}\n$contentEyes',
          front: [
            chawanAt(100, 107, s: 0.8),
            pawAt(84, 104, r: 6.5),
            pawAt(116, 104, r: 6.5),
            // Dampf seitlich, damit er die Augen nicht verdeckt.
            shift(48, -38, steam(step)),
          ].join('\n'),
          headRot: step == 0 ? -2 : 2,
        ),
        1300,
      ),
  ]),
];

void main() {
  final dir = Directory('assets/kuma')..createSync(recursive: true);
  for (final f in dir.listSync()) {
    if (f.path.endsWith('.svg')) f.deleteSync();
  }
  final out = StringBuffer()
    ..writeln('// GENERIERT von tool/gen_kuma.dart – nicht von Hand ändern.')
    ..writeln("import 'figure.dart';")
    ..writeln()
    ..writeln('/// Posen von Kumachan, der kleinen Teemeisterin.')
    ..writeln('enum KumaPose implements FigurePose {');
  for (final p in poses) {
    final files = <String>[];
    for (final (i, (svg, _)) in p.frames.indexed) {
      final file = '${p.name}_$i.svg';
      File('${dir.path}/$file').writeAsStringSync(svg);
      files.add("'$file'");
    }
    out
      ..writeln('  /// ${p.title}')
      ..writeln('  ${p.name}([${files.join(', ')}], [${p.frames.map((f) => f.$2).join(', ')}]),');
    stdout.writeln('${p.name}: ${files.length} Bilder');
  }
  out
    ..writeln('  ;')
    ..writeln()
    ..writeln('  const KumaPose(this.frames, this.ms);')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  final List<String> frames;')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  final List<int> ms;')
    ..writeln()
    ..writeln('  /// Knopfaugen blinzeln nicht.')
    ..writeln('  @override')
    ..writeln('  String? get blink => null;')
    ..writeln()
    ..writeln('  @override')
    ..writeln("  String get folder => 'kuma';")
    ..writeln()
    ..writeln('  /// Seitenverhältnis Breite/Höhe der Bilder.')
    ..writeln('  @override')
    ..writeln('  double get aspect => 200 / 300;')
    ..writeln('}');
  File('lib/widgets/kuma_poses.g.dart').writeAsStringSync(out.toString());
}
