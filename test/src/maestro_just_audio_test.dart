import 'package:maestro/maestro.dart';
import 'package:maestro_just_audio/maestro_just_audio.dart';
import 'package:test/test.dart';

void main() {
  group('MaestroJustAudio', () {
    test('can be created', () {
      expect(createMaestro(), isA<Maestro>());
    });
  });
}
