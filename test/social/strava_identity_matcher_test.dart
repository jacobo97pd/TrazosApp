import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/social/strava_identity_matcher.dart';

void main() {
  const matcher = StravaIdentityMatcher();

  RunnerDirectoryEntry e(String uid,
          {bool strava = true, bool disc = true, String? aid = 'a'}) =>
      RunnerDirectoryEntry(
          uid: uid,
          stravaAthleteId: aid,
          stravaConnected: strava,
          discoverable: disc);

  test('sugiere corredores opt-in con Strava conectado', () {
    final out = matcher.suggestions(
      meUid: 'me',
      meDiscoverable: true,
      candidates: [e('a'), e('b')],
    );
    expect(out.map((c) => c.uid), ['a', 'b']);
  });

  test('si YO no soy descubrible, no se sugiere a nadie', () {
    final out = matcher.suggestions(
      meUid: 'me',
      meDiscoverable: false,
      candidates: [e('a')],
    );
    expect(out, isEmpty);
  });

  test('excluye a quien no ha activado el descubrimiento', () {
    final out = matcher.suggestions(
      meUid: 'me',
      meDiscoverable: true,
      candidates: [e('a', disc: false), e('b')],
    );
    expect(out.map((c) => c.uid), ['b']);
  });

  test('excluye sin Strava, sin athleteId, a mí mismo y a excluidos', () {
    final out = matcher.suggestions(
      meUid: 'me',
      meDiscoverable: true,
      candidates: [
        e('me'),
        e('nostrava', strava: false),
        e('noaid', aid: null),
        e('blocked'),
        e('ok'),
      ],
      excludedUids: {'blocked'},
    );
    expect(out.map((c) => c.uid), ['ok']);
  });
}
