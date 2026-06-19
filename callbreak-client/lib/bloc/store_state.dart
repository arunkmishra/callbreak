import 'package:equatable/equatable.dart';
import '../data/models/store_models.dart';

enum StoreStatus { initial, loading, loaded, error }

class StoreState extends Equatable {
  final StoreStatus status;
  final WalletState? wallet;
  final List<StoreItem> items;
  final String? errorMessage;

  const StoreState({
    this.status = StoreStatus.initial,
    this.wallet,
    this.items = const [],
    this.errorMessage,
  });

  StoreState copyWith({
    StoreStatus? status,
    WalletState? wallet,
    List<StoreItem>? items,
    String? errorMessage,
  }) {
    return StoreState(
      status: status ?? this.status,
      wallet: wallet ?? this.wallet,
      items: items ?? this.items,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isPremium => wallet?.isPremiumSubscriber ?? false;
  int get coinBalance => wallet?.coinBalance ?? 0;
  List<String> get unlockedSkins => wallet?.unlockedSkins ?? [];

  @override
  List<Object?> get props => [status, wallet, items, errorMessage];
}
