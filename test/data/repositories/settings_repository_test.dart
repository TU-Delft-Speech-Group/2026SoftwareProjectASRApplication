import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../testing/utils/paramaterize.dart';

@GenerateMocks([SaveFunction])
import 'settings_repository_test.mocks.dart';

abstract class SaveFunction {
  Future<void> call(String key, String value);
}

void main() {
  group('SettingsRepository', () {
    late MockSaveFunction saveFunc;

    setUp(() {
      saveFunc = MockSaveFunction();
    });

    test(
      'it should instantiate without previously saved preferences and use defaults',
      () {
        Map<String, String> preferences = {};
        SettingsRepository settingsRepository = SettingsRepository(
          save: saveFunc.call,
          preferences: preferences,
        );

        expect(settingsRepository, isA<SettingsRepository>());
      },
    );

    group('fontsize', () {
      test('it should use the default fontsize', () {
        Map<String, String> preferences = {};
        SettingsRepository settingsRepository = SettingsRepository(
          save: saveFunc.call,
          preferences: preferences,
        );

        expect(
          settingsRepository.getFontsize(),
          SettingsRepository.getDefaultFontsize(),
        );
      });

      test('it should use the stored fontsize', () {
        AppFontSizeOption fontsize = AppFontSizeOption.large;
        Map<String, String> preferences = {'settings_fontsize': fontsize.name};
        SettingsRepository settingsRepository = SettingsRepository(
          save: saveFunc.call,
          preferences: preferences,
        );

        expect(settingsRepository.getFontsize(), fontsize);
      });

      each('fontsize options', [
        AppFontSizeOption.medium,
        AppFontSizeOption.large,
        AppFontSizeOption.xl,
      ])((AppFontSizeOption fontsize) {
        test('it should set fontsize ${fontsize.name}', () async {
          Map<String, String> preferences = {};
          SettingsRepository settingsRepository = SettingsRepository(
            save: saveFunc.call,
            preferences: preferences,
          );

          await settingsRepository.setFontsize(fontsize);
          expect(settingsRepository.getFontsize(), fontsize);
        });
      });

      test('it should store the fontsize', () async {
        Map<String, String> preferences = {};
        SettingsRepository settingsRepository = SettingsRepository(
          save: saveFunc.call,
          preferences: preferences,
        );

        AppFontSizeOption fontsize = AppFontSizeOption.medium;
        await settingsRepository.setFontsize(fontsize);

        verify(saveFunc.call('settings_fontsize', fontsize.name)).called(1);
      });
    });

    group('locale', () {
      test('it should use the default locale', () {
        Map<String, String> preferences = {};
        SettingsRepository settingsRepository = SettingsRepository(
          save: saveFunc.call,
          preferences: preferences,
        );

        expect(
          settingsRepository.getLocale(),
          SettingsRepository.getDefaultLocale(),
        );
      });

      test('it should use the stored locale', () {
        String languageCode = 'nl';
        Map<String, String> preferences = {'settings_locale': languageCode};
        SettingsRepository settingsRepository = SettingsRepository(
          save: saveFunc.call,
          preferences: preferences,
        );

        expect(settingsRepository.getLocale(), Locale(languageCode));
      });

      test('it should set the locale', () async {
        String languageCode = 'nl';
        Map<String, String> preferences = {'settings_locale': languageCode};
        SettingsRepository settingsRepository = SettingsRepository(
          save: saveFunc.call,
          preferences: preferences,
        );
        expect(settingsRepository.getLocale().languageCode, languageCode);

        languageCode = 'en';
        await settingsRepository.setLocale(Locale(languageCode));
        expect(settingsRepository.getLocale().languageCode, languageCode);
      });

      test('it should store the locale', () async {
        Map<String, String> preferences = {};
        SettingsRepository settingsRepository = SettingsRepository(
          save: saveFunc.call,
          preferences: preferences,
        );

        Locale locale = Locale('en');
        await settingsRepository.setLocale(locale);

        verify(saveFunc.call('settings_locale', locale.languageCode)).called(1);
      });
    });

    group('model', () {
      test('it should not have a default modelName', () {
        Map<String, String> preferences = {};
        SettingsRepository settingsRepository = SettingsRepository(
          save: saveFunc.call,
          preferences: preferences,
        );

        expect(settingsRepository.getModelName(), isNull);
      });

      test('it should use the stored modelName', () {
        Map<String, String> preferences = {'settings_model': 'model1'};
        SettingsRepository settingsRepository = SettingsRepository(
          save: saveFunc.call,
          preferences: preferences,
        );

        expect(settingsRepository.getModelName(), 'model1');
      });

      test('it should set the modelName', () async {
        Map<String, String> preferences = {'settings_model': 'model1'};
        SettingsRepository settingsRepository = SettingsRepository(
          save: saveFunc.call,
          preferences: preferences,
        );
        expect(settingsRepository.getModelName(), 'model1');

        await settingsRepository.setModelName('model2');
        expect(settingsRepository.getModelName(), 'model2');
      });

      test('it should store the modelName', () async {
        Map<String, String> preferences = {};
        SettingsRepository settingsRepository = SettingsRepository(
          save: saveFunc.call,
          preferences: preferences,
        );

        String modelName = 'model2';
        await settingsRepository.setModelName(modelName);

        verify(saveFunc.call('settings_model', modelName)).called(1);
      });
    });
  });
}
