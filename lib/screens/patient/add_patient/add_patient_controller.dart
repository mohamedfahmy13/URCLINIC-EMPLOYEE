import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../../api/core_apis.dart';
import '../../../main.dart';
import '../../../utils/colors.dart';
import '../../../utils/common_base.dart';
import '../../../utils/constants.dart';
import '../../Encounter/add_encounter/model/patient_model.dart';
import '../../auth/model/common_model.dart';

/// Add a walk-in patient or edit one (receptionist). Arguments: a [PatientModel] to edit,
/// or the search text typed in a patient picker to pre-fill a new patient.
/// Closes with the saved [PatientModel] as the result.
class AddPatientController extends GetxController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  TextEditingController firstNameCont = TextEditingController();
  TextEditingController lastNameCont = TextEditingController();
  TextEditingController emailCont = TextEditingController();
  TextEditingController phoneCont = TextEditingController();
  TextEditingController dateOfBirthCont = TextEditingController();
  TextEditingController addressCont = TextEditingController();

  FocusNode firstNameFocus = FocusNode();
  FocusNode lastNameFocus = FocusNode();
  FocusNode phoneFocus = FocusNode();
  FocusNode emailFocus = FocusNode();
  FocusNode addressFocus = FocusNode();

  Rx<Country> pickedPhoneCode = defaultCountry.obs;
  Rx<CMNModel> selectedGender = CMNModel().obs;
  Rx<PatientModel> patient = PatientModel().obs;
  RxBool isLoading = false.obs;

  bool get isEdit => !patient.value.id.isNegative;

  @override
  void onInit() {
    final dynamic args = Get.arguments;
    if (args is PatientModel) {
      patient(args);
      _fillFrom(args);
    } else if (args is String && args.trim().isNotEmpty) {
      _prefillFromSearch(args.trim());
    }
    super.onInit();
  }

  void _fillFrom(PatientModel p) {
    firstNameCont.text = p.firstName;
    lastNameCont.text = p.lastName;
    emailCont.text = p.email;
    dateOfBirthCont.text = p.dateOfBirth;
    addressCont.text = p.address;
    selectedGender(genders.firstWhere((g) => g.slug == p.gender.toLowerCase(), orElse: () => CMNModel()));

    // Same parsing as the receptionist form: "+966 5..." -> country code + local number.
    try {
      final phoneData = p.mobile.extractPhoneCodeAndNumber;
      phoneCont.text = phoneData.$2;
      final String phoneCode = phoneData.$1;
      if (phoneCode.isNotEmpty && phoneCode != "0") {
        try {
          pickedPhoneCode(CountryParser.parsePhoneCode(phoneCode));
        } catch (_) {
          final List<Country> matches = CountryService().getAll().where((c) => c.phoneCode == phoneCode).toList()
            ..sort((a, b) => a.name.length.compareTo(b.name.length));
          if (matches.isNotEmpty) pickedPhoneCode(matches.first);
        }
      }
    } catch (e) {
      phoneCont.text = p.mobile.trim();
      log('AddPatient phone parse: $e');
    }
  }

  /// Digits typed in the search go to the mobile number, anything else to the name.
  void _prefillFromSearch(String text) {
    if (RegExp(r'^[+\d\s-]+$').hasMatch(text)) {
      phoneCont.text = text.replaceAll(RegExp(r'[^0-9]'), '');
    } else {
      final List<String> parts = text.split(RegExp(r'\s+'));
      firstNameCont.text = parts.first;
      if (parts.length > 1) lastNameCont.text = parts.sublist(1).join(' ');
    }
  }

  Future<void> pickDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(dateOfBirthCont.text) ?? DateTime(DateTime.now().year - 25),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      dateOfBirthCont.text = picked.formatDateYYYYmmdd();
    }
  }

  Future<void> save() async {
    hideKeyBoardWithoutContext();
    if (isLoading.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (selectedGender.value.slug.isEmpty) {
      toast(locale.value.pleaseSelectGender);
      return;
    }

    final Map<String, dynamic> request = {
      'first_name': firstNameCont.text.trim(),
      'last_name': lastNameCont.text.trim(),
      'mobile': "+${phoneCont.text.trim().formatPhoneNumber(pickedPhoneCode.value.phoneCode)}",
      'email': emailCont.text.trim(),
      'gender': selectedGender.value.slug,
      'date_of_birth': dateOfBirthCont.text.trim(),
      'address': addressCont.text.trim(),
    };

    isLoading(true);
    try {
      final PatientModel saved = await CoreServiceApis.savePatient(
        request: request,
        patientId: isEdit ? patient.value.id : null,
      );
      toast(isEdit ? locale.value.patientUpdatedSuccessfully : locale.value.patientAddedSuccessfully);
      Get.back(result: saved);
    } on ExistingPatientException catch (e) {
      isLoading(false);
      if (isEdit || Get.context == null) {
        toast(e.message);
      } else {
        _offerExistingPatient(e);
      }
    } catch (e) {
      toast(e.toString(), print: true);
    } finally {
      isLoading(false);
    }
  }

  /// A walk-in may already have an account (e.g. from the patient app): offer to use it.
  Future<void> _offerExistingPatient(ExistingPatientException e) async {
    // The dialog closes itself; leave this screen only after it has (else the wrong route pops).
    final bool? useExisting = await showConfirmDialogCustom(
      Get.context!,
      primaryColor: appColorPrimary,
      title: "${e.message}\n${e.patient.fullName}",
      positiveText: locale.value.useExistingPatient,
      negativeText: locale.value.cancel,
      onAccept: (_) {},
    );
    if (useExisting == true) Get.back(result: e.patient);
  }

  @override
  void onClose() {
    firstNameFocus.dispose();
    lastNameFocus.dispose();
    phoneFocus.dispose();
    emailFocus.dispose();
    addressFocus.dispose();
    super.onClose();
  }
}
