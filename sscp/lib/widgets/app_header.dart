import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final Color backgroundColor;

  const AppHeader({
    super.key,
    this.backgroundColor = const Color(0xFF1e3a5f),
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: backgroundColor,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 12 : 16,
      ),
      child: Center(
        child: Container(
          height: isMobile ? 60 : 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: Image.asset(
            'images/image.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.school,
                size: isMobile ? 40 : 60,
                color: Colors.grey[400],
              );
            },
          ),
        ),
      ),
    );
  }
}
