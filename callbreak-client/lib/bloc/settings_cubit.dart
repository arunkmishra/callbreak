import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/audio_service.dart';

enum TableColor { green, red, blue }

class SettingsState {
  final TableColor tableColor;
  final bool soundEnabled;
  final bool isLoaded;

  const SettingsState({
    this.tableColor = TableColor.green,
    this.soundEnabled = true,
    this.isLoaded = false,
  });

  SettingsState copyWith({
    TableColor? tableColor,
    bool? soundEnabled,
    bool? isLoaded,
  }) {
    return SettingsState(
      tableColor: tableColor ?? this.tableColor,
      soundEnabled: soundEnabled ?? this.soundEnabled,
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

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorIndex = prefs.getInt(_colorKey) ?? 0;
      final soundEnabled = prefs.getBool(_soundKey) ?? true;
      
      final color = TableColor.values.length > colorIndex 
          ? TableColor.values[colorIndex] 
          : TableColor.green;
      
      AudioService.toggleSound(soundEnabled);

      emit(state.copyWith(
        tableColor: color,
        soundEnabled: soundEnabled,
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
}
