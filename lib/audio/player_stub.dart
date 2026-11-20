// Außerhalb des Browsers (Tests) gibt es kein Audio.
Future<void> play(String url, {required double rate, void Function()? onEnded, String? sprich}) async {}

void speak(String text, {void Function()? onEnded}) {}

void setRate(double rate) {}

void stop() {}
