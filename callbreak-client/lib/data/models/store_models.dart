class WalletState {
  final int coinBalance;
  final bool isPremiumSubscriber;
  final List<String> unlockedSkins;

  WalletState({
    required this.coinBalance,
    required this.isPremiumSubscriber,
    required this.unlockedSkins,
  });

  factory WalletState.fromJson(Map<String, dynamic> json) {
    return WalletState(
      coinBalance: json['coinBalance'] as int? ?? 0,
      isPremiumSubscriber: json['isPremiumSubscriber'] as bool? ?? false,
      unlockedSkins: (json['unlockedSkins'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class StoreItem {
  final String id;
  final String category;
  final String name;
  final int price;
  final String? previewUrl;

  StoreItem({
    required this.id,
    required this.category,
    required this.name,
    required this.price,
    this.previewUrl,
  });

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    return StoreItem(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: json['price'] as int? ?? 0,
      previewUrl: json['previewUrl'] as String?,
    );
  }
}
