import 'package:flutter/material.dart';

import '../utils/colors.dart';

class LoaderWidget extends StatelessWidget {
  final bool isBlurBackground;
  final Color? loaderColor;

  const LoaderWidget({super.key, this.loaderColor, this.isBlurBackground = false});

  @override
  Widget build(BuildContext context) {
    final loader = Center(
      child: CircularProgressIndicator(color: loaderColor ?? appColorPrimary),
    );
    if (isBlurBackground) {
      return AbsorbPointer(
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9),
          child: loader,
        ),
      );
    }
    return loader;
  }
}
