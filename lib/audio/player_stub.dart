// Außerhalb des Browsers (Tests) gibt es kein Audio.
Future<void> play(String url, {required double rate, void Function()? onEnded}) async {}

void setRate(double rate) {}

void stop() {}
