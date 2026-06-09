// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:get/get.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:kivicare_clinic_admin/utils/app_common.dart';
import 'package:kivicare_clinic_admin/utils/local_storage.dart';
import '../api/auth_apis.dart';
import '../utils/common_base.dart';
import '../utils/constants.dart';
import '../utils/secure_storage_helper.dart';
import 'auth/model/app_configuration_res.dart';
import 'auth/model/login_response.dart';
import 'auth/sign_in_sign_up/signin_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'home/home_controller.dart';

class SplashScreenController extends GetxController {
  Rx<Future<ConfigurationResponse>> appConfigsFuture =
      Future(() => appConfigs.value).obs;
  RxBool isLoading = false.obs;
  RxBool hasNetworkError = false.obs;

  // Navigation is deferred until the splash video finishes so the clip isn't
  // cut off. The computed navigation (if any) is held until then.
  bool _videoFinished = false;
  void Function()? _pendingNavigation;
  Timer? _fallbackTimer;

  @override
  void onInit() {
    super.onInit();
    //Get Package Info
    getPackageInfo().then((value) => currentPackageinfo(value));
    init();

    // Safety fallback: never trap the user on the splash if the video fails
    // to load or never reports completion.
    _fallbackTimer = Timer(const Duration(seconds: 10), onVideoFinished);
  }

  @override
  void onClose() {
    _fallbackTimer?.cancel();
    super.onClose();
  }

  /// Called by the splash screen once the video finishes (or fails to load).
  void onVideoFinished() {
    _videoFinished = true;
    final pending = _pendingNavigation;
    _pendingNavigation = null;
    pending?.call();
  }

  /// Runs [nav] now if the video already finished, otherwise holds it until it
  /// does. The most recent computed navigation wins.
  void _navigate(void Function() nav) {
    if (_videoFinished) {
      nav();
    } else {
      _pendingNavigation = nav;
    }
  }

  void retry() {
    hasNetworkError(false);
    init();
  }

  @override
  void onReady() {
    try {
      final getThemeFromLocal =
          getValueFromLocal(SettingsLocalConst.THEME_MODE);
      if (getThemeFromLocal is int) {
        toggleThemeMode(themeId: getThemeFromLocal);
      } else {
        toggleThemeMode(themeId: THEME_MODE_LIGHT);
      }
    } catch (e) {
      log('getThemeFromLocal from cache E: $e');
    }

    super.onReady();
  }

  void init() {
    getAppConfigurations();
  }

  ///Get ChooseService List
  void getAppConfigurations() {
    isLoading(true);
    appConfigsFuture(AuthServiceApis.getAppConfigurations()).then((value) async {
      appCurrency(value.currency);
      appConfigs(value);

      /// Place ChatGPT Key Here
      chatGPTAPIkey = value.chatgptKey;

      ///Navigation logic
      if (getValueFromLocal(SharedPreferenceConst.IS_LOGGED_IN) == true) {
        try {
          final userData = getValueFromLocal(SharedPreferenceConst.USER_DATA);
          isLoggedIn(true);
          loginUserData.value = UserData.fromJson(userData);
          selectedAppClinic(loginUserData.value.selectedClinic);

          if (!value.isMultiVendor &&
              loginUserData.value.userRole.contains(EmployeeKeyConst.vendor)) {
            AuthServiceApis.clearData();
            _navigate(() => Get.offAll(() => SignInScreen()));
            return;
          }

          if (loginUserData.value.userRole.contains(EmployeeKeyConst.doctor) &&
              selectedAppClinic.value.id.isNegative) {
            AuthServiceApis.clearData();
            _navigate(() => Get.offAll(() => SignInScreen()));
          } else {
            _navigate(() => Get.offAll(
                  () => DashboardScreen(),
                  binding: BindingsBuilder(() {
                    Get.put(HomeController());
                  }),
                ));
          }
        } catch (e) {
          log('SplashScreenController Err: $e');
          _navigate(() => Get.offAll(() => SignInScreen()));
        }
      } else if (getValueFromLocal(SharedPreferenceConst.IS_REMEMBER_ME) == true) {
        // Auto-login with saved credentials
        try {
          await _attemptAutoLogin();
        } catch (e) {
          log('Auto-login failed: $e');
          _navigate(() => Get.offAll(() => SignInScreen()));
        }
      } else {
        _navigate(() => Get.offAll(() => SignInScreen()));
      }
    }).onError((error, stackTrace) {
      log('getAppConfigurations error: $error');
      hasNetworkError(true);
    }).whenComplete(() => isLoading(false));
  }

  Future<void> _attemptAutoLogin() async {
    try {
      final savedEmail = getValueFromLocal(SharedPreferenceConst.USER_EMAIL);
      final savedUserType = getValueFromLocal(SharedPreferenceConst.USER_TYPE);
      final savedPassword = await SecureStorageHelper.getUserPassword();

      if (savedEmail is String &&
          savedEmail.isNotEmpty &&
          savedPassword.isNotEmpty &&
          savedUserType is String &&
          savedUserType.isNotEmpty) {
        log('Attempting auto-login for user: $savedEmail');

        final Map<String, dynamic> req = {
          'email': savedEmail,
          'password': savedPassword,
          UserKeys.userType: savedUserType,
        };

        final loginResponse = await AuthServiceApis.loginUser(request: req);

        if (loginResponse.userData.userRole.contains(EmployeeKeyConst.vendor) ||
            loginResponse.userData.userRole.contains(EmployeeKeyConst.doctor) ||
            loginResponse.userData.userRole.contains(EmployeeKeyConst.receptionist) ||
            loginResponse.userData.userRole.contains(EmployeeKeyConst.pharma)) {
          // Auto-login successful
          loginUserData(loginResponse.userData);
          loginUserData.value.userType = savedUserType;
          setValueToLocal(SharedPreferenceConst.USER_DATA, loginUserData.toJson());
          isLoggedIn(true);
          selectedAppClinic(loginResponse.userData.selectedClinic);

          log('Auto-login successful for user: $savedEmail');

          if (loginResponse.userData.userRole.contains(EmployeeKeyConst.doctor) &&
              selectedAppClinic.value.id.isNegative) {
            _navigate(() => Get.offAll(() => SignInScreen()));
          } else {
            _navigate(() => Get.offAll(
                  () => DashboardScreen(),
                  binding: BindingsBuilder(() {
                    Get.put(HomeController());
                  }),
                ));
          }
        } else {
          _navigate(() => Get.offAll(() => SignInScreen()));
        }
      } else {
        _navigate(() => Get.offAll(() => SignInScreen()));
      }
    } catch (e) {
      log('Auto-login error: $e');
      rethrow;
    }
  }
}
