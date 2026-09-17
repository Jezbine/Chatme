import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatme/services/status_service.dart';
import 'package:chatme/services/moments_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Statuts (Stories 24h) - Tests unitaires', () {
    test('StatusItem calcule correctement l\'expiration', () {
      final now = DateTime.now();
      final activeItem = StatusItem(
        id: 's1',
        type: 'image',
        text: 'Bonjour le Bénin !',
        mediaPath: 'https://example.com/story.jpg',
        durationMinutes: 1440,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );

      expect(activeItem.isExpired, false);

      final expiredItem = StatusItem(
        id: 's2',
        type: 'text',
        text: 'Ancien statut',
        durationMinutes: 60,
        createdAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(hours: 1)),
      );

      expect(expiredItem.isExpired, true);
    });

    test('ContactStatus filtre correctement les éléments actifs', () {
      final now = DateTime.now();
      final contactStatus = ContactStatus(
        id: 'c1',
        name: 'Awa',
        initials: 'AW',
        colorValue: 0xFF3C3489,
        items: [
          StatusItem(
            id: 's_exp',
            type: 'text',
            text: 'Expiré',
            durationMinutes: 1,
            createdAt: now.subtract(const Duration(minutes: 5)),
            expiresAt: now.subtract(const Duration(minutes: 4)),
          ),
          StatusItem(
            id: 's_act',
            type: 'video',
            text: 'Vidéo active',
            mediaPath: 'https://example.com/video.mp4',
            durationMinutes: 1440,
            createdAt: now,
            expiresAt: now.add(const Duration(hours: 24)),
          ),
        ],
      );

      expect(contactStatus.hasActive, true);
      final activeOnly = contactStatus.items.where((i) => !i.isExpired).toList();
      expect(activeOnly.length, 1);
      expect(activeOnly.first.id, 's_act');
      expect(activeOnly.first.type, 'video');
    });

    test('StatusItem sérialisation JSON aller-retour', () {
      final now = DateTime.now();
      final item = StatusItem(
        id: 's_json',
        type: 'image',
        text: 'Test JSON',
        mediaPath: 'https://chatme.app/media.jpg',
        durationMinutes: 1440,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );

      final json = item.toJson();
      final restored = StatusItem.fromJson(json);

      expect(restored.id, item.id);
      expect(restored.type, item.type);
      expect(restored.text, item.text);
      expect(restored.mediaPath, item.mediaPath);
      expect(restored.durationMinutes, item.durationMinutes);
    });
  });

  group('Moments (Feed Social) - Tests unitaires', () {
    test('Moment et MomentComment sérialisation et désérialisation', () {
      final moment = Moment(
        id: 'm100',
        name: 'Kofi',
        initials: 'KO',
        colorValue: 0xFF1D9E75,
        time: "Il y a 5min",
        text: 'Superbe journée à Cotonou ☀️',
        photoPath: 'https://example.com/cotonou.jpg',
        likes: 12,
        liked: true,
        comments: [
          MomentComment(author: 'Marc', text: 'Magnifique !'),
          MomentComment(author: 'Fatou', text: 'Profite bien !'),
        ],
      );

      final json = moment.toJson();
      expect(json['id'], 'm100');
      expect(json['likes'], 12);
      expect(json['liked'], true);
      expect((json['comments'] as List).length, 2);

      final restored = Moment.fromJson(json);
      expect(restored.id, moment.id);
      expect(restored.name, moment.name);
      expect(restored.text, moment.text);
      expect(restored.photoPath, moment.photoPath);
      expect(restored.likes, 12);
      expect(restored.liked, true);
      expect(restored.comments.length, 2);
      expect(restored.comments.first.author, 'Marc');
      expect(restored.comments.first.text, 'Magnifique !');
    });
  });
}
