import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/services/shake_detection_service.dart';

class AppSettingsState {
  final String theme;
  final String language;
  final double speechRate;
  final double speechPitch;
  final bool shakeActivation;
  final bool wakeWordEnabled;
  final bool notificationEnabled;
  final bool isLoading;

  AppSettingsState({
    this.theme = 'dark',
    this.language = 'en',
    this.speechRate = 0.5,
    this.speechPitch = 1.0,
    this.shakeActivation = true,
    this.wakeWordEnabled = true,
    this.notificationEnabled = true,
    this.isLoading = true,
  });

  AppSettingsState copyWith({
    String? theme,
    String? language,
    double? speechRate,
    double? speechPitch,
    bool? shakeActivation,
    bool? wakeWordEnabled,
    bool? notificationEnabled,
    bool? isLoading,
  }) {
    return AppSettingsState(
      theme: theme ?? this.theme,
      language: language ?? this.language,
      speechRate: speechRate ?? this.speechRate,
      speechPitch: speechPitch ?? this.speechPitch,
      shakeActivation: shakeActivation ?? this.shakeActivation,
      wakeWordEnabled: wakeWordEnabled ?? this.wakeWordEnabled,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsController extends StateNotifier<AppSettingsState> {
  final Ref _ref;

  SettingsController(this._ref) : super(AppSettingsState()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final repo = _ref.read(localRepositoryProvider);
    state = state.copyWith(isLoading: true);

    final theme = await repo.getSetting('theme') ?? 'dark';
    final lang = await repo.getSetting('language') ?? 'en';
    final rateStr = await repo.getSetting('speech_rate') ?? '0.5';
    final pitchStr = await repo.getSetting('speech_pitch') ?? '1.0';
    final shakeStr = await repo.getSetting('shake_activation') ?? 'true';
    final wakeStr = await repo.getSetting('wake_word') ?? 'true';
    final notifyStr = await repo.getSetting('notification_enabled') ?? 'true';

    state = AppSettingsState(
      theme: theme,
      language: lang,
      speechRate: double.tryParse(rateStr) ?? 0.5,
      speechPitch: double.tryParse(pitchStr) ?? 1.0,
      shakeActivation: shakeStr == 'true',
      wakeWordEnabled: wakeStr == 'true',
      notificationEnabled: notifyStr == 'true',
      isLoading: false,
    );

    // Apply speech rate, pitch and language to the TTS engine
    _ref.read(ttsServiceProvider).setRate(state.speechRate);
    _ref.read(ttsServiceProvider).setPitch(state.speechPitch);
    _ref.read(ttsServiceProvider).setLanguageCode(state.language);

    // Apply language to the speech recognition engine
    _ref.read(speechServiceProvider).setLanguageCode(state.language);

    // Apply shake activation preference
    if (state.shakeActivation) {
      ShakeDetectionService.startDetection();
    } else {
      ShakeDetectionService.stopDetection();
    }
  }

  Future<void> updateTheme(String theme) async {
    state = state.copyWith(theme: theme);
    await _ref.read(localRepositoryProvider).saveSetting('theme', theme);
  }

  Future<void> updateLanguage(String lang) async {
    state = state.copyWith(language: lang);
    await _ref.read(localRepositoryProvider).saveSetting('language', lang);
    // Immediately switch the TTS voice to match the chosen language.
    _ref.read(ttsServiceProvider).setLanguageCode(lang);
    // Also switch the speech recognition language to match the chosen language.
    _ref.read(speechServiceProvider).setLanguageCode(lang);
  }

  Future<void> updateSpeechRate(double rate) async {
    state = state.copyWith(speechRate: rate);
    await _ref
        .read(localRepositoryProvider)
        .saveSetting('speech_rate', rate.toString());
    await _ref.read(ttsServiceProvider).setRate(rate);
  }

  Future<void> updateSpeechPitch(double pitch) async {
    state = state.copyWith(speechPitch: pitch);
    await _ref
        .read(localRepositoryProvider)
        .saveSetting('speech_pitch', pitch.toString());
    await _ref.read(ttsServiceProvider).setPitch(pitch);
  }

  Future<void> updateShakeActivation(bool value) async {
    state = state.copyWith(shakeActivation: value);
    await _ref
        .read(localRepositoryProvider)
        .saveSetting('shake_activation', value.toString());
    if (value) {
      ShakeDetectionService.startDetection();
    } else {
      ShakeDetectionService.stopDetection();
    }
  }

  Future<void> updateWakeWord(bool value) async {
    state = state.copyWith(wakeWordEnabled: value);
    await _ref
        .read(localRepositoryProvider)
        .saveSetting('wake_word', value.toString());
  }

  Future<void> updateNotifications(bool value) async {
    state = state.copyWith(notificationEnabled: value);
    await _ref
        .read(localRepositoryProvider)
        .saveSetting('notification_enabled', value.toString());
  }

  Future<void> wipeAllUserData() async {
    state = state.copyWith(isLoading: true);
    await _ref.read(localRepositoryProvider).wipeAllData();
    await loadSettings();
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettingsState>((ref) {
      return SettingsController(ref);
    });
