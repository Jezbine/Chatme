import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chatme/services/settings_service.dart';
import 'package:chatme/core/utils/format_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    // Mock flutter_secure_storage platform channel pour les tests unitaires
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Authentification & Profil - Sécurité 2FA & Formatage', () {
    late SettingsService settingsService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsService = SettingsService();
      await settingsService.init();
    });

    test('Vérification 2FA - activation avec code PIN 6 chiffres valide', () async {
      expect(settingsService.twoStepVerification.value, isFalse);
      expect(settingsService.twoStepPin.value, isEmpty);

      final ok = await settingsService.setTwoStepPin('123456');
      expect(ok, isTrue);
      expect(settingsService.twoStepVerification.value, isTrue);
      expect(settingsService.twoStepPin.value, equals('123456'));
    });

    test('Vérification 2FA - rejet des codes PIN invalides (< 6 chiffres, lettres, > 6 chiffres)', () async {
      final tooShort = await settingsService.setTwoStepPin('12345');
      expect(tooShort, isFalse);

      final withLetters = await settingsService.setTwoStepPin('12345a');
      expect(withLetters, isFalse);

      final tooLong = await settingsService.setTwoStepPin('1234567');
      expect(tooLong, isFalse);

      expect(settingsService.twoStepVerification.value, isFalse);
    });

    test('Vérification 2FA - validation et rejet du code PIN saisi', () async {
      await settingsService.setTwoStepPin('654321');

      final rightPin = await settingsService.verifyTwoStepPin('654321');
      expect(rightPin, isTrue);

      final wrongPin = await settingsService.verifyTwoStepPin('111111');
      expect(wrongPin, isFalse);
    });

    test('Vérification 2FA - désactivation réinitialise l\'état et le PIN', () async {
      await settingsService.setTwoStepPin('999888');
      expect(settingsService.twoStepVerification.value, isTrue);

      await settingsService.disableTwoStep();
      expect(settingsService.twoStepVerification.value, isFalse);
      expect(settingsService.twoStepPin.value, isEmpty);
    });

    test('Formatage téléphone Bénin 10 chiffres (norme 2024)', () {
      expect(FormatUtils.formatBeninPhone('+2290197000000'), equals('+229 01 97 00 00 00'));
      expect(FormatUtils.formatBeninPhone('0197000000'), equals('+229 01 97 00 00 00'));
      expect(FormatUtils.formatBeninPhone('+33612345678'), equals('+33612345678'));
    });
  });
}

