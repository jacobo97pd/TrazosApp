import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/conquest/conquest_post.dart';
import 'package:runrace/conquest/story_service.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);

  ConquestPost post({
    required String id,
    ConquestType type = ConquestType.photo,
    DateTime? expiresAt,
    bool isArchived = false,
    bool isDeleted = false,
  }) =>
      ConquestPost(
        id: id,
        userId: 'user-1',
        type: type,
        visibility: ConquestVisibility.connections,
        createdAt: now.subtract(const Duration(hours: 1)),
        expiresAt: expiresAt,
        isArchived: isArchived,
        isDeleted: isDeleted,
      );

  group('StoryService', () {
    test('usa 24 horas como duracion por defecto', () {
      const service = StoryService();

      expect(
        service.expiresAtFrom(now),
        now.add(const Duration(hours: 24)),
      );
    });

    test('admite una duracion configurable', () {
      const service = StoryService(
        config: StoryConfig(duration: Duration(hours: 12)),
      );

      expect(
        service.expiresAtFrom(now),
        now.add(const Duration(hours: 12)),
      );
    });

    test('la duracion puntual prevalece sobre la configuracion', () {
      const service = StoryService(
        config: StoryConfig(duration: Duration(hours: 12)),
      );

      expect(
        service.expiresAtFrom(now, duration: const Duration(hours: 2)),
        now.add(const Duration(hours: 2)),
      );
    });
  });

  group('StoryExpirationService', () {
    const service = StoryExpirationService();

    test('expiresAt define la historia sin cambiar el tipo del post', () {
      for (final type in [
        ConquestType.photo,
        ConquestType.selfie,
        ConquestType.text,
      ]) {
        final story = post(
          id: type.name,
          type: type,
          expiresAt: now.add(const Duration(minutes: 1)),
        );

        expect(story.type, type);
        expect(story.isStory, isTrue);
        expect(service.isActive(story, now), isTrue);
      }
    });

    test('esta activa antes del limite y no en el instante de expiracion', () {
      final expiresAt = now.add(const Duration(hours: 1));
      final story = post(id: 'story-1', expiresAt: expiresAt);

      expect(
        service.isActive(
          story,
          expiresAt.subtract(const Duration(microseconds: 1)),
        ),
        isTrue,
      );
      expect(service.isActive(story, expiresAt), isFalse);
      expect(
        service.isActive(
          story,
          expiresAt.add(const Duration(microseconds: 1)),
        ),
        isFalse,
      );
    });

    test('un post permanente, archivado o borrado no esta activo', () {
      final future = now.add(const Duration(hours: 1));

      expect(service.isActive(post(id: 'permanent'), now), isFalse);
      expect(
        service.isActive(
          post(id: 'archived', expiresAt: future, isArchived: true),
          now,
        ),
        isFalse,
      );
      expect(
        service.isActive(
          post(id: 'deleted', expiresAt: future, isDeleted: true),
          now,
        ),
        isFalse,
      );
    });

    test('calcula el tiempo restante y lo limita a cero', () {
      final active = post(
        id: 'active',
        expiresAt: now.add(const Duration(minutes: 90)),
      );
      final expired = post(
        id: 'expired',
        expiresAt: now.subtract(const Duration(seconds: 1)),
      );

      expect(service.timeRemaining(active, now), const Duration(minutes: 90));
      expect(service.timeRemaining(expired, now), Duration.zero);
      expect(service.timeRemaining(post(id: 'permanent'), now), Duration.zero);
    });

    test('activeOnly filtra y conserva el orden de entrada', () {
      final activePhoto = post(
        id: 'photo',
        type: ConquestType.photo,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      final expiredText = post(
        id: 'text',
        type: ConquestType.text,
        expiresAt: now.subtract(const Duration(seconds: 1)),
      );
      final activeSelfie = post(
        id: 'selfie',
        type: ConquestType.selfie,
        expiresAt: now.add(const Duration(hours: 2)),
      );
      final archived = post(
        id: 'archived',
        expiresAt: now.add(const Duration(hours: 2)),
        isArchived: true,
      );

      expect(
        service.activeOnly(
          [activePhoto, expiredText, activeSelfie, archived],
          now,
        ).map((item) => item.id),
        ['photo', 'selfie'],
      );
    });
  });
}
