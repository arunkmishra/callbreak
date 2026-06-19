import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repositories/store_repository.dart';
import 'store_event.dart';
import 'store_state.dart';

class StoreBloc extends Bloc<StoreEvent, StoreState> {
  final StoreRepository repository;

  StoreBloc({required this.repository}) : super(const StoreState()) {
    on<LoadStore>(_onLoadStore);
    on<PurchaseItem>(_onPurchaseItem);
    on<WatchAdReward>(_onWatchAdReward);
  }

  Future<void> _onLoadStore(LoadStore event, Emitter<StoreState> emit) async {
    emit(state.copyWith(status: StoreStatus.loading));
    try {
      final items = await repository.getStoreItems();
      final wallet = await repository.getWallet();
      if (wallet != null) {
        emit(state.copyWith(status: StoreStatus.loaded, items: items, wallet: wallet));
      } else {
        emit(state.copyWith(status: StoreStatus.error, errorMessage: 'Failed to load wallet.'));
      }
    } catch (e) {
      emit(state.copyWith(status: StoreStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onPurchaseItem(PurchaseItem event, Emitter<StoreState> emit) async {
    try {
      final newWallet = await repository.purchaseItem(event.itemId);
      if (newWallet != null) {
        emit(state.copyWith(wallet: newWallet));
      } else {
        emit(state.copyWith(errorMessage: 'Purchase failed: Insufficient coins.'));
        emit(state.copyWith(errorMessage: '')); // Clear immediately so it triggers next time
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
      emit(state.copyWith(errorMessage: ''));
    }
  }

  Future<void> _onWatchAdReward(WatchAdReward event, Emitter<StoreState> emit) async {
    try {
      final newWallet = await repository.rewardAd(amount: event.amount);
      if (newWallet != null) {
        emit(state.copyWith(wallet: newWallet));
      }
    } catch (e) {
      // Handle error
    }
  }
}
