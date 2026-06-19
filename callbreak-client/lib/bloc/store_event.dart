import 'package:equatable/equatable.dart';
import '../data/models/store_models.dart';

abstract class StoreEvent extends Equatable {
  const StoreEvent();

  @override
  List<Object?> get props => [];
}

class LoadStore extends StoreEvent {}

class PurchaseItem extends StoreEvent {
  final String itemId;
  const PurchaseItem(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

class WatchAdReward extends StoreEvent {
  final int amount;

  const WatchAdReward(this.amount);

  @override
  List<Object?> get props => [amount];
}
