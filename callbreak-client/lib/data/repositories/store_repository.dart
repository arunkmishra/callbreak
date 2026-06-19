import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../models/store_models.dart';

class StoreRepository {
  final http.Client _client;

  StoreRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<String?> _getToken() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return null;
    return session.accessToken;
  }

  Future<WalletState?> getWallet() async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      final response = await _client.get(
        Uri.parse('$kHttpBaseUrl/api/users/wallet'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return WalletState.fromJson(json);
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  Future<List<StoreItem>> getStoreItems() async {
    try {
      final response = await _client.get(
        Uri.parse('$kHttpBaseUrl/api/store/items'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((j) => StoreItem.fromJson(j)).toList();
      }
    } catch (e) {
      // Ignore
    }
    return [];
  }

  Future<WalletState?> purchaseItem(String itemId) async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      final response = await _client.post(
        Uri.parse('$kHttpBaseUrl/api/store/purchase'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'itemId': itemId}),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return WalletState.fromJson(json);
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  Future<WalletState?> rewardAd({int amount = 10}) async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      final response = await _client.post(
        Uri.parse('$kHttpBaseUrl/api/store/reward-ad'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'amount': amount}),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return WalletState.fromJson(json);
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }
}
