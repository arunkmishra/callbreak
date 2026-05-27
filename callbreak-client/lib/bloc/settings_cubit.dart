import 'package:flutter_bloc/flutter_bloc.dart';

enum TableColor { green, red, blue }

class SettingsState {
  final TableColor tableColor;
  final bool soundEnabled;

  const SettingsState({
    this.tableColor = TableColor.green,
    this.soundEnabled = true,
  });

  SettingsState copyWith({
    TableColor? tableColor,
    bool? soundEnabled,
  }) {
    return SettingsState(
      tableColor: tableColor ?? this.tableColor,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  void setTableColor(TableColor color) {
    emit(state.copyWith(tableColor: color));
  }

  void toggleSound() {
    emit(state.copyWith(soundEnabled: !state.soundEnabled));
  }
}
