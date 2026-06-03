import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String username;
  final double radius;
  final Color backgroundColor;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    required this.username,
    required this.radius,
    required this.backgroundColor,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final initials = username.isNotEmpty ? username[0].toUpperCase() : '?';

    Widget inner;
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      inner = _buildInitials(initials);
    } else {
      inner = ClipOval(
        child: Image.network(
          avatarUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitials(initials),
        ),
      );
    }

    if (border != null || boxShadow != null) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: border,
          boxShadow: boxShadow,
        ),
        child: inner,
      );
    }

    return inner;
  }

  Widget _buildInitials(String initials) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: radius * 0.85,
          ),
        ),
      ),
    );
  }
}
