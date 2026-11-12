/// Inhalte der Einstufung zu Beginn (Spezifikation 9.2). Die JLPT-Stufen der
/// Wörter sind mit `tool/teekueche/daten/jlpt_woerter.json` geprüft.
library;

class PruefWort {
  const PruefWort(this.t, this.r, this.de, this.jlpt);
  final String t;
  final String r;
  final String de;
  final int jlpt;
}

const einstufungWoerter = [
  PruefWort('天気', 'てんき', 'Wetter', 5),
  PruefWort('先生', 'せんせい', 'Lehrer, Lehrerin', 5),
  PruefWort('買う', 'かう', 'kaufen', 5),
  PruefWort('新しい', 'あたらしい', 'neu', 5),
  PruefWort('毎朝', 'まいあさ', 'jeden Morgen', 5),
  PruefWort('駅', 'えき', 'Bahnhof', 5),
  PruefWort('飲む', 'のむ', 'trinken', 5),
  PruefWort('友達', 'ともだち', 'Freund, Freundin', 5),
  PruefWort('時間', 'じかん', 'Zeit', 5),
  PruefWort('近い', 'ちかい', 'nah', 5),
  PruefWort('準備', 'じゅんび', 'Vorbereitung', 4),
  PruefWort('経験', 'けいけん', 'Erfahrung', 4),
  PruefWort('届ける', 'とどける', 'bringen, zustellen', 4),
  PruefWort('複雑', 'ふくざつ', 'kompliziert', 4),
  PruefWort('招待', 'しょうたい', 'Einladung', 4),
  PruefWort('習慣', 'しゅうかん', 'Gewohnheit', 4),
  PruefWort('壊れる', 'こわれる', 'kaputtgehen', 4),
  PruefWort('遠慮', 'えんりょ', 'Zurückhaltung', 4),
  PruefWort('説明', 'せつめい', 'Erklärung', 4),
  PruefWort('安心', 'あんしん', 'beruhigt sein', 4),
  PruefWort('環境', 'かんきょう', 'Umwelt', 3),
  PruefWort('意識', 'いしき', 'Bewusstsein', 3),
  PruefWort('減る', 'へる', 'weniger werden', 3),
  PruefWort('確認', 'かくにん', 'Überprüfung', 3),
  PruefWort('移動', 'いどう', 'Ortswechsel', 3),
  PruefWort('普段', 'ふだん', 'im Alltag, normalerweise', 3),
  PruefWort('効果', 'こうか', 'Wirkung', 3),
  PruefWort('状態', 'じょうたい', 'Zustand', 3),
  PruefWort('影響', 'えいきょう', 'Einfluss', 3),
  PruefWort('支払う', 'しはらう', 'bezahlen', 3),
  PruefWort('対策', 'たいさく', 'Gegenmaßnahme', 2),
  PruefWort('姿勢', 'しせい', 'Haltung', 2),
  PruefWort('統計', 'とうけい', 'Statistik', 2),
  PruefWort('募集', 'ぼしゅう', 'Ausschreibung, Anwerbung', 2),
  PruefWort('補う', 'おぎなう', 'ergänzen, ausgleichen', 2),
  PruefWort('目指す', 'めざす', 'anstreben', 2),
  PruefWort('険しい', 'けわしい', 'steil, schroff', 2),
  PruefWort('素直', 'すなお', 'aufrichtig', 2),
  PruefWort('普及', 'ふきゅう', 'Verbreitung', 2),
  PruefWort('継続', 'けいぞく', 'Fortsetzung', 2),
];

class MiniFrage {
  const MiniFrage(this.frage, this.antworten);
  final String frage;

  /// Die erste Antwort ist richtig; die App mischt sie.
  final List<String> antworten;
}

class MiniText {
  const MiniText({required this.jlpt, required this.text, required this.fragen});
  final int jlpt;

  /// Text mit Furigana in Ruby-Schreibweise ({漢字|かんじ}), nur für Wörter
  /// oberhalb der Stufe.
  final String text;
  final List<MiniFrage> fragen;

  /// Zeichen ohne Furigana – für das Lesetempo.
  int get chars => text.replaceAllMapped(RegExp(r'\{([^|{}]+)\|[^{}]+\}'), (m) => m[1]!).length;
}

const einstufungTexte = [
  MiniText(
    jlpt: 4,
    text: '先週、駅の近くに小さなお茶の店ができました。店の人は{京都|きょうと}で十年お茶の勉強をしたそうです。'
        '店では日本茶だけでなく、お茶を使ったお{菓子|かし}も売っています。'
        'わたしは週末に友達と行って、ほうじ茶とお{菓子|かし}を注文しました。'
        'お茶はとても{香|かお}りがよくて、お{菓子|かし}はあまり甘くなかったです。'
        '{値段|ねだん}は少し高いですが、また行きたいと思いました。',
    fragen: [
      MiniFrage('店の人について、正しいものはどれですか。', [
        '{京都|きょうと}でお茶の勉強をした',
        '毎週{京都|きょうと}に行っている',
        'お{菓子|かし}の作り方を教えている',
        '十年前に駅の近くに店を作った',
      ]),
      MiniFrage('「わたし」はこの店についてどう思っていますか。', [
        '少し高いが、また行きたい',
        '安いので、毎日行きたい',
        'お{菓子|かし}が甘すぎた',
        'お茶の{香|かお}りがよくなかった',
      ]),
    ],
  ),
  MiniText(
    jlpt: 3,
    text: '最近、古着を買う若者が増えている。古着は{新品|しんぴん}より安いだけでなく、'
        'ほかの人と同じにならない服が見つかるのが{魅力|みりょく}だという。'
        'また、服を捨てずに長く使うことは、環境にもやさしい。'
        '一方で、古着は一着ずつ状態が違うので、買う前によく確認する必要がある。'
        'インターネットで買う場合は、写真だけでは分からないこともあるため、'
        '店で実際に手に取って選ぶ人も多い。',
    fragen: [
      MiniFrage('古着のよい点として、本文に書かれていないものはどれか。', [
        '品質がいつも同じだ',
        '{新品|しんぴん}より安い',
        'ほかの人と違う服が見つかる',
        '環境にやさしい',
      ]),
      MiniFrage('店で古着を選ぶ人が多いのはなぜか。', [
        '写真だけでは分からないことがあるから',
        'インターネットでは古着が買えないから',
        '店のほうが値段が安いから',
        '店の人が選んでくれるから',
      ]),
    ],
  ),
  MiniText(
    jlpt: 2,
    text: '緑茶の消費量は、ここ二十年ほどで減少傾向にある。とはいえ、お茶そのものが飲まれなくなったわけではない。'
        'ペットボトル入りのお茶は今や日常生活に欠かせない存在であり、'
        '{急須|きゅうす}で入れる習慣が薄れたというのが実情だろう。'
        'こうした変化を受け、若い世代に向けて手軽に楽しめる商品を開発する生産者も出てきた。'
        '一方で、茶葉本来の香りや味わいを知ってもらうには、{急須|きゅうす}で入れる体験が欠かせないという声も根強い。'
        '伝統を守りつつ時代に合わせることを、いかに両立させるかが問われている。',
    fragen: [
      MiniFrage('「お茶そのものが飲まれなくなったわけではない」とあるが、なぜそう言えるのか。', [
        'ペットボトルのお茶が日常的に飲まれているから',
        '{急須|きゅうす}で入れる人が増えているから',
        '緑茶の消費量が増えているから',
        '若い世代が茶葉を好むようになったから',
      ]),
      MiniFrage('筆者が最も言いたいことは何か。', [
        '伝統と時代の変化をどう両立させるかが課題だ',
        'ペットボトルのお茶は伝統を壊している',
        '{急須|きゅうす}で入れる習慣はもう必要ない',
        '若い世代はお茶に関心がない',
      ]),
    ],
  ),
];
