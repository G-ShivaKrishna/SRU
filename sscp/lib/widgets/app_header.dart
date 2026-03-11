import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final Color backgroundColor;

  /// Override back-button visibility.
  /// null (default) = auto-detect via Navigator.canPop.
  /// false = never show. true = always show.
  final bool? showBack;

  const AppHeader({
    super.key,
    this.backgroundColor = const Color(0xFF1e3a5f),
    this.showBack,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final canPop = showBack ?? Navigator.canPop(context);

    return Container(
      color: backgroundColor,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 12 : 16,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Container(
              height: isMobile ? 60 : 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.school,
                size: isMobile ? 40 : 60,
                color: const Color(0xFF1e3a5f),
              ),
            ),
          ),
          if (canPop)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: isMobile ? 20 : 24,
                  ),
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
