// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../../main.dart';
import '../../clinic/model/clinics_res_model.dart';
import '../../dashboard/dashboard_screen.dart';
import '../../home/choose_clinic_screen.dart';
import '../../home/home_controller.dart';
import '../model/clinic_center_argument_model.dart';
import '../model/login_response.dart';
import '../../../api/auth_apis.dart';
import '../../../utils/app_common.dart';
import '../../../utils/common_base.dart';
import '../../../utils/constants.dart';
import '../../../utils/local_storage.dart';
import '../../../utils/secure_storage_helper.dart';
import '../model/login_roles_model.dart';
import '../services/social_logins.dart';

class SignInController extends GetxController {
  RxBool isNavigateToDashboard = false.obs;
  final GlobalKey<FormState> signInformKey = GlobalKey();

  RxBool isRememberMe = false.obs;
  RxBool isLoading = false.obs;
  RxString userName = "".obs;

  TextEditingController emailCont = TextEditingController();
  TextEditingController passwordCont = TextEditingController();

  FocusNode emailFocus = FocusNode();
  FocusNode passwordFocus = FocusNode();

  Rx<LoginRoleData> selectedLoginRole = receptionistLoginRole.obs;

  void toggleSwitch() {
    isRememberMe.value = !isRememberMe.value;
  }

  @override
  void onInit() async {
    if (appConfigs.value.isDummyCredential != 1) {
      emailCont.text = '';
      passwordCont.text = '';
      isRememberMe.value = false;
    }

    // Migrate old plaintext password once, then remove insecure value.
    final legacyPassword =
        getValueFromLocal(SharedPreferenceConst.USER_PASSWORD);
    if (legacyPassword is String && legacyPassword.isNotEmpty) {
      await SecureStorageHelper.saveUserPassword(legacyPassword);
      removeValueFromLocal(SharedPreferenceConst.USER_PASSWORD);
    }

    final savedRememberMe =
        getValueFromLocal(SharedPreferenceConst.IS_REMEMBER_ME) ?? false;
    isRememberMe.value = savedRememberMe;

    if (!appConfigs.value.isMultiVendor &&
        (getValueFromLocal(SharedPreferenceConst.IS_REMEMBER_ME) ?? false)) {
      removeValueFromLocal(SharedPreferenceConst.IS_REMEMBER_ME);
    }
    if (Get.arguments is bool) {
      isNavigateToDashboard(Get.arguments == true);
    }
    final userIsRemeberMe =
        getValueFromLocal(SharedPreferenceConst.IS_REMEMBER_ME);
    final userNameFromLocal =
        getValueFromLocal(SharedPreferenceConst.USER_NAME);
    if (userNameFromLocal is String) {
      userName(userNameFromLocal);
    }
    if (userIsRemeberMe == true) {
      final userEmail = getValueFromLocal(SharedPreferenceConst.USER_EMAIL);
      if (userEmail is String) {
        emailCont.text = userEmail;
      }
      final userPASSWORD = await SecureStorageHelper.getUserPassword();
      if (userPASSWORD.isNotEmpty) {
        passwordCont.text = userPASSWORD;
      }
    }

    super.onInit();
  }

  Future<void> saveForm() async {
    hideKeyBoardWithoutContext();
    if (!selectedLoginRole.value.id.isNegative) {
      isLoading(true);
      final Map<String, dynamic> req = {
        'email': emailCont.text.trim(),
        'password': passwordCont.text.trim(),
        UserKeys.userType: selectedLoginRole.value.userType,
      };

      await AuthServiceApis.loginUser(request: req).then((value) async {
        await handleLoginResponse(loginResponse: value);
      }).catchError((e) {
        isLoading(false);
        final msg = e.toString().toLowerCase();
        if (msg.contains('credentials') || msg.contains('unauthori')) {
          toast(locale.value.invalidEmailOrPassword, print: true);
        } else {
          toast(e.toString(), print: true);
        }
      });
    } else {
      toast(locale.value.pleaseSelectRoleToLogin);
    }
  }

  Future<void> googleSignIn() async {
    isLoading(true);
    await GoogleSignInAuthService.signInWithGoogle().then((value) async {
      final Map request = {
        UserKeys.contactNumber: value.mobile,
        UserKeys.email: value.email,
        UserKeys.firstName: value.firstName,
        UserKeys.lastName: value.lastName,
        UserKeys.username: value.userName,
        UserKeys.profileImage: value.profileImage,
        UserKeys.userType: selectedLoginRole.value.userType,
        UserKeys.loginType: LoginTypeConst.LOGIN_TYPE_GOOGLE,
      };
      log('signInWithGoogle REQUEST: $request');

      /// Social Login Api
      await AuthServiceApis.loginUser(request: request, isSocialLogin: true)
          .then((value) async {
        await handleLoginResponse(loginResponse: value, isSocialLogin: true);
      }).catchError((e) {
        isLoading(false);
        toast(e.toString(), print: true);
      });
    }).catchError((e) {
      isLoading(false);
      toast(e.toString(), print: true);
    });
  }

  Future<void> appleSignIn() async {
    isLoading(true);
    await GoogleSignInAuthService.signInWithApple().then((value) async {
      final Map request = {
        UserKeys.contactNumber: value.mobile,
        UserKeys.email: value.email,
        UserKeys.firstName: value.firstName,
        UserKeys.lastName: value.lastName,
        UserKeys.username: value.userName,
        UserKeys.profileImage: value.profileImage,
        UserKeys.userType: selectedLoginRole.value.userType,
        UserKeys.loginType: LoginTypeConst.LOGIN_TYPE_APPLE,
      };
      log('signInWithGoogle REQUEST: $request');

      /// Social Login Api
      await AuthServiceApis.loginUser(request: request, isSocialLogin: true)
          .then((value) async {
        await handleLoginResponse(loginResponse: value, isSocialLogin: true);
      }).catchError((e) {
        isLoading(false);
        toast(e.toString(), print: true);
      });
    }).catchError((e) {
      isLoading(false);
      toast(e.toString(), print: true);
    });
  }

  Future<void> handleLoginResponse(
      {required UserResponse loginResponse, bool isSocialLogin = false}) async {
    if (loginResponse.userData.userRole.contains(EmployeeKeyConst.vendor) ||
        loginResponse.userData.userRole.contains(EmployeeKeyConst.doctor) ||
        loginResponse.userData.userRole
            .contains(EmployeeKeyConst.receptionist) ||
        loginResponse.userData.userRole.contains(EmployeeKeyConst.pharma)) {
       loginUserData(loginResponse.userData);
      loginUserData.value.isSocialLogin = isSocialLogin;
      loginUserData.value.userType = selectedLoginRole.value.userType;
      setValueToLocal(SharedPreferenceConst.USER_DATA, loginUserData.toJson());
      setValueToLocal(SharedPreferenceConst.USER_EMAIL, emailCont.text.trim());
      setValueToLocal(SharedPreferenceConst.USER_NAME, loginResponse.userData.userName);
      setValueToLocal(SharedPreferenceConst.USER_TYPE, selectedLoginRole.value.userType);
      if (isSocialLogin) {
        await SecureStorageHelper.clearUserPassword();
      } else {
        await SecureStorageHelper.saveUserPassword(passwordCont.text.trim());
      }
      removeValueFromLocal(SharedPreferenceConst.USER_PASSWORD);
      isLoggedIn(true);
      setValueToLocal(SharedPreferenceConst.IS_LOGGED_IN, true);
      setValueToLocal(SharedPreferenceConst.IS_REMEMBER_ME, true);
      if (loginResponse.userData.userRole.contains(EmployeeKeyConst.pharma)) {
        selectedAppClinic(loginResponse.userData.selectedClinic);
        /* selectedAppCommission(loginResponse.userData.commission);
        log("commission length----${selectedAppCommission.length}");*/
        //setValueToLocal(SharedPreferenceConst.COMMISSION, loginResponse.userData.commission);
      }
      if (loginUserData.value.userRole.contains(EmployeeKeyConst.doctor) &&
          selectedAppClinic.value.id.isNegative) {
        Get.to(
          () => ChooseClinicScreen(),
          arguments: ClinicCenterArgumentModel(
            selectedClinc: selectedAppClinic.value,
          ),
        )?.then((value) {
          if (value is ClinicData) {
            selectedAppClinic(value);
            loginUserData.value.selectedClinic = value;
            setValueToLocal(
                SharedPreferenceConst.USER_DATA, loginUserData.toJson());
            Get.offAll(
              () => DashboardScreen(),
              binding: BindingsBuilder(() {
                Get.put(HomeController());
              }),
            );
          }
        });
      } else {
        Get.offAll(
          () => DashboardScreen(),
          binding: BindingsBuilder(() {
            Get.put(HomeController());
          }),
        );
      }
    } else {
      toast(locale.value.sorryUserCannotSignin);
    }
    isLoading(false);
  }
}
