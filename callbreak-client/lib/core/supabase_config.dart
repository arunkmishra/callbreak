import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Access Supabase credentials from the .env file.
/// 
/// SUPABASE_URL and SUPABASE_ANON_KEY are loaded from the .env asset file.
/// These are the only Supabase keys that belong in the Flutter client.
/// The JWT secret lives exclusively on the backend.
class SupabaseConfig {
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
