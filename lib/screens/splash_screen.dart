import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:kivicare_clinic_admin/utils/colors.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:video_player/video_player.dart';
import '../components/app_scaffold.dart';
import 'splash_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SplashScreenController splashController =
      Get.put(SplashScreenController());

  late final VideoPlayerController _videoController;
  bool _initialized = false;
  bool _finishedNotified = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/IMG_8356.MP4')
      ..setLooping(false)
      ..addListener(_onVideoTick);

    _videoController.initialize().then((_) {
      _videoController.setVolume(1.0);
      _videoController.play();
      if (mounted) setState(() => _initialized = true);
    }).catchError((_) {
      // Video couldn't load — let navigation proceed.
      _notifyFinished();
    });
  }

  void _onVideoTick() {
    final value = _videoController.value;
    if (value.hasError) {
      _notifyFinished();
      return;
    }
    if (value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      _notifyFinished();
    }
  }

  void _notifyFinished() {
    if (_finishedNotified) return;
    _finishedNotified = true;
    splashController.onVideoFinished();
  }

  @override
  void dispose() {
    _videoController.removeListener(_onVideoTick);
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      hideAppBar: true,
      scaffoldBackgroundColor: splashVideoBackgroundColor,
      body: Stack(
        alignment: Alignment.center,
        children: [
          if (_initialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            ),
          Positioned(
            height: Get.height * 0.3,
            bottom: 0,
            child: Obx(
              () => splashController.hasNetworkError.value
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              color: appColorPrimary, size: 36),
                          12.height,
                          Text(
                            'No internet connection',
                            style: boldTextStyle(size: 14),
                            textAlign: TextAlign.center,
                          ),
                          6.height,
                          Text(
                            'Please check your connection and try again.',
                            style: secondaryTextStyle(size: 12),
                            textAlign: TextAlign.center,
                          ),
                          16.height,
                          ElevatedButton.icon(
                            onPressed: splashController.retry,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appColorPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
