import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final supabaseUrl = 'https://yicfaolfudlcuxxkmbnv.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlpY2Zhb2xmdWRsY3V4eGttYm52Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAxNjU4NjAsImV4cCI6MjA5NTc0MTg2MH0.ximLahal6F98GIiTZWmeAyKEvfybzWybFJETd-5igw4';

  final response = await http.post(
    Uri.parse('$supabaseUrl/auth/v1/signup'),
    headers: {
      'apikey': anonKey,
      'Authorization': 'Bearer $anonKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({}),
  );

  print('Response: ' + response.statusCode.toString() + ' ' + response.body);
  if (response.statusCode == 200) {
    final body = jsonDecode(response.body);
    final token = body['access_token'];
    print('Token: ' + token.toString());
    
    // Decode token header
    final parts = token.split('.');
    if (parts.length > 0) {
      var base64Str = parts[0];
      while (base64Str.length % 4 != 0) {
        base64Str += '=';
      }
      final headerStr = utf8.decode(base64Decode(base64Str));
      print('Header: ' + headerStr);
    }
  }
}
