import 'package:flutter_test/flutter_test.dart';
import 'package:chatme/core/utils/format_utils.dart';
import 'package:chatme/services/contacts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Contacts & Répertoire - Tests unitaires', () {
    test('formatBeninPhone formate correctement 10 chiffres', () {
      expect(FormatUtils.formatBeninPhone('+2290197000000'), '+229 01 97 00 00 00');
      expect(FormatUtils.formatBeninPhone('2290197000000'), '+229 01 97 00 00 00');
      expect(FormatUtils.formatBeninPhone('0197000000'), '+229 01 97 00 00 00');
      expect(FormatUtils.formatBeninPhone(''), '');
    });

    test('QR Code payload - génération et décodage', () {
      const uid = 'b9b3846e-1d5f-4a0b-93f5-76b4b45efae2';
      const name = 'Jean Dupont';

      final payload = buildUserQrPayload(uid, name);
      expect(payload.startsWith('chatme:user:'), true);

      final parsed = parseUserQrPayload(payload);
      expect(parsed, isNotNull);
      expect(parsed!['id'], uid);
      expect(parsed['name'], name);
    });

    test('AddedContact sérialisation et désérialisation', () {
      final contact = AddedContact(
        id: '1234-uuid',
        name: 'Awa Cisse',
        initials: 'AC',
        colorValue: 0xFF3C3489,
        addedAt: DateTime(2026, 9, 17),
        phoneNumber: '+2290197000000',
        avatarUrl: 'https://example.com/avatar.jpg',
      );

      final json = contact.toJson();
      expect(json['id'], '1234-uuid');
      expect(json['phoneNumber'], '+2290197000000');

      final reconstructed = AddedContact.fromJson(json);
      expect(reconstructed.id, contact.id);
      expect(reconstructed.name, contact.name);
      expect(reconstructed.initials, contact.initials);
      expect(reconstructed.phoneNumber, contact.phoneNumber);
      expect(reconstructed.avatarUrl, contact.avatarUrl);
    });
  });
}

