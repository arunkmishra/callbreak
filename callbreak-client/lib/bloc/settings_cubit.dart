import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/audio_service.dart';

enum TableColor { green, red, blue }

class SettingsState {
  final TableColor tableColor;
  final bool soundEnabled;
  final double soundVolume;
  final bool isLoaded;

  const SettingsState({
    this.tableColor = TableColor.blue,
    this.soundEnabled = true,
    this.soundVolume = 1.0,
    this.isLoaded = false,
  });

  SettingsState copyWith({
    TableColor? tableColor,
    bool? soundEnabled,
    double? soundVolume,
    bool? isLoaded,
  }) {
    return SettingsState(
      tableColor: tableColor ?? this.tableColor,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundVolume: soundVolume ?? this.soundVolume,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState()) {
    _loadSettings();
  }

  static const _colorKey = 'settings_table_color';
  static const _soundKey = 'settings_sound_enabled';
  static const _volumeKey = 'settings_sound_volume';

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorIndex = prefs.getInt(_colorKey) ?? TableColor.blue.index;
      final soundEnabled = prefs.getBool(_soundKey) ?? true;
      final soundVolume = prefs.getDouble(_volumeKey) ?? 1.0;
      
      final color = TableColor.values.length > colorIndex 
          ? TableColor.values[colorIndex] 
          : TableColor.blue;
      
      AudioService.toggleSound(soundEnabled);
      AudioService.setVolume(soundVolume);

      emit(state.copyWith(
        tableColor: color,
        soundEnabled: soundEnabled,
        soundVolume: soundVolume,
        isLoaded: true,
      ));
    } catch (e) {
      // Fallback if shared_preferences fails
      emit(state.copyWith(isLoaded: true));
    }
  }

  Future<void> setTableColor(TableColor color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_colorKey, color.index);
    } catch (_) {}
    emit(state.copyWith(tableColor: color));
  }

  Future<void> toggleSound() async {
    final newValue = !state.soundEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundKey, newValue);
    } catch (_) {}
    
    AudioService.toggleSound(newValue);
    emit(state.copyWith(soundEnabled: newValue));
  }

  Future<void> setVolume(double volume) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_volumeKey, volume);
    } catch (_) {}
    
    AudioService.setVolume(volume);
    emit(state.copyWith(soundVolume: volume));
  }

  Future<void> restoreDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_colorKey, TableColor.blue.index);
      await prefs.setBool(_soundKey, true);
      await prefs.setDouble(_volumeKey, 1.0);
    } catch (_) {}
    
    AudioService.toggleSound(true);
    AudioService.setVolume(1.0);
    
    emit(state.copyWith(
      tableColor: TableColor.blue,
      soundEnabled: true,
      soundVolume: 1.0,
    ));
  }
}
