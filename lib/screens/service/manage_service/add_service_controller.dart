import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kivicare_clinic_admin/screens/service/model/service_list_model.dart';
import 'package:kivicare_clinic_admin/utils/colors.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../api/clinic_api.dart';
import '../../../main.dart';
import '../../../utils/app_common.dart';
import '../../../utils/common_base.dart';
import '../../../utils/constants.dart';
import '../../category/model/all_category_model.dart';
import '../../clinic/model/clinics_res_model.dart';
import 'service_apis.dart';

class CreateServiceController extends GetxController {
  TextEditingController serviceCont = TextEditingController();
  TextEditingController serviceArCont = TextEditingController();
  TextEditingController durationCont = TextEditingController();
  TextEditingController priceCont = TextEditingController();
  TextEditingController categoryCont = TextEditingController();
  TextEditingController clinicCont = TextEditingController();
  TextEditingController typeCont = TextEditingController();
  TextEditingController searchCont = TextEditingController();
  TextEditingController clinicSearchCont = TextEditingController();
  TextEditingController descriptionCont = TextEditingController();
  TextEditingController descriptionArCont = TextEditingController();

  FocusNode serviceNameFocus = FocusNode();
  FocusNode serviceNameArFocus = FocusNode();
  FocusNode serviceDurationFocus = FocusNode();
  FocusNode defaultPriceFocus = FocusNode();
  FocusNode descriptionFocus = FocusNode();
  FocusNode descriptionArFocus = FocusNode();

  Rx<ServiceElement> serviceData = ServiceElement(status: false.obs).obs;

  RxBool isLoading = false.obs;
  RxBool isClinicLoading = false.obs;
  RxBool hasErrorFetchingCategory = false.obs;
  RxBool hasErrorFetchingClinic = false.obs;
  RxBool isEdit = false.obs;
  RxBool status = true.obs;

  RxString errorMessageCategory = "".obs;
  RxString errorMessageClinic = "".obs;
  RxString serviceImage = "".obs;

  RxList<PlatformFile> serviceFiles = RxList();

  // Category
  Rx<CategoryElement> selectedCategoryType = CategoryElement().obs;
  RxList<CategoryElement> categoryList = RxList();
  RxList<CategoryElement> categoryFilterList = RxList();

  // Clinic
  Rx<ClinicData> selectedClinic = ClinicData().obs;
  RxList<ClinicData> clinicList = RxList();
  StreamController<String> clinicSearchStream = StreamController<String>.broadcast();

  // Type
  final List<Map<String, String>> typeOptions = [
    {'key': ServiceTypes.inClinic, 'label': 'In Clinic'},
    {'key': ServiceTypes.online, 'label': 'Online'},
  ];
  RxString selectedType = ''.obs;
  RxString selectedTypeLabel = ''.obs;

  Rx<File> imageFile = File("").obs;
  XFile? pickedFile;

  final GlobalKey<FormState> addClinicformKey = GlobalKey<FormState>();

  final ScrollController scrollController = ScrollController();

  @override
  void onInit() {
    final dynamic args = Get.arguments;

    if (args is ServiceElement) {
      serviceData(args);
      isEdit(true);
      _populateFromService(args);
    } else if (args is ClinicData) {
      // Pre-select clinic from clinic detail screen
      selectedClinic(args);
      clinicCont.text = args.name;
    }

    clinicSearchStream.stream.debounce(const Duration(milliseconds: 500)).listen((s) {
      getClinics();
    });

    super.onInit();
  }

  void _populateFromService(ServiceElement svc) {
    serviceCont.text = svc.name;
    durationCont.text = svc.duration > 0 ? svc.duration.toString() : '';
    priceCont.text = svc.charges > 0 ? svc.charges.toString() : '';
    descriptionCont.text = svc.description;
    typeCont.text = _typeLabelFromKey(svc.type);
    selectedType.value = svc.type;
    selectedTypeLabel.value = _typeLabelFromKey(svc.type);
    status(svc.status.value);
    serviceImage(svc.serviceImage);
  }

  String _typeLabelFromKey(String key) {
    if (key == ServiceTypes.inClinic) return locale.value.inClinic;
    if (key == ServiceTypes.online) return locale.value.online;
    return key;
  }

  Future<void> handleFilesPickerClick() async {
    final pickedFiles = await pickFiles();
    final Set<String> filePathsSet = serviceFiles.map((file) => file.name.trim().toLowerCase()).toSet();
    for (var i = 0; i < pickedFiles.length; i++) {
      if (!filePathsSet.contains(pickedFiles[i].name.trim().toLowerCase())) {
        serviceFiles.add(pickedFiles[i]);
      }
    }
  }

  // Get Category List
  void getCategory() {
    isLoading(true);
    ServiceFormApis.getCategory().then((value) {
      isLoading(false);
      categoryList(value.data);
      hasErrorFetchingCategory(false);
    }).onError((error, stackTrace) {
      hasErrorFetchingCategory(true);
      errorMessageCategory(error.toString());
      isLoading(false);
    });
  }

  // Get Clinic List
  Future<void> getClinics() async {
    isClinicLoading(true);
    hasErrorFetchingClinic(false);
    final List<ClinicData> tmp = [];
    try {
      await ClinicApis.getClinicList(
        page: 1,
        perPage: 50,
        clinicList: tmp,
        search: clinicSearchCont.text.trim(),
      );
      clinicList(tmp);
    } catch (e) {
      hasErrorFetchingClinic(true);
      errorMessageClinic(e.toString());
    } finally {
      isClinicLoading(false);
    }
  }

  void searchCategoryFunc({
    required String searchtext,
    required RxList<CategoryElement> categoryFilterList,
    required RxList<CategoryElement> categorySList,
  }) {
    categoryFilterList.value = List.from(categorySList.where((element) => element.name.toLowerCase().contains(searchtext.toLowerCase())));
  }

  void onCategorySearchChange(String searchtext) {
    searchCategoryFunc(
      searchtext: searchtext,
      categoryFilterList: categoryFilterList,
      categorySList: categoryList,
    );
  }

  bool get isShowFullList => categoryFilterList.isEmpty && searchCont.text.trim().isEmpty;

  void selectClinic(ClinicData clinic) {
    selectedClinic(clinic);
    clinicCont.text = clinic.name;
  }

  void selectType(Map<String, String> type) {
    selectedType.value = type['key'] ?? '';
    selectedTypeLabel.value = type['label'] ?? '';
    typeCont.text = type['label'] ?? '';
  }

  Future<void> updateServicesStatus({required int id, required int status}) async {
    isLoading(true);
    hideKeyBoardWithoutContext();

    ServiceFormApis.updateServicesStatus(serviceId: id, request: {"status": status}).then((value) {
      Get.back(result: true);
      isLoading(false);
    }).catchError((e) {
      isLoading(false);
      toast(e.toString());
    });
  }

  bool _validate() {
    if (selectedClinic.value.id.isNegative) {
      toast(locale.value.pleaseSelectClinic);
      return false;
    }
    if (serviceCont.text.trim().isEmpty) {
      toast(locale.value.pleaseEnterServiceName);
      return false;
    }
    if (serviceArCont.text.trim().isEmpty) {
      toast(locale.value.pleaseEnterServiceNameAr);
      return false;
    }
    if (durationCont.text.trim().isEmpty || (int.tryParse(durationCont.text.trim()) ?? 0) <= 0) {
      toast(locale.value.pleaseEnterDuration);
      return false;
    }
    if (priceCont.text.trim().isEmpty || (num.tryParse(priceCont.text.trim()) ?? -1) < 0) {
      toast(locale.value.pleaseEnterDefaultPrice);
      return false;
    }
    if (selectedType.value.isEmpty) {
      toast(locale.value.pleaseSelectType);
      return false;
    }
    return true;
  }

  Future<void> saveService() async {
    if (!_validate()) return;
    if (isLoading.value) return;

    // Scope the service to the clinic owner's vendor so it shows up in
    // get-services (which filters by vendor_id). For receptionists, the
    // logged-in user id is NOT the vendor — the clinic's createdBy is.
    final int clinicVendorId = !selectedClinic.value.createdBy.isNegative
        ? selectedClinic.value.createdBy
        : loginUserData.value.id;

    final Map<String, dynamic> request = {
      'name': serviceCont.text.trim(),
      'name_ar': serviceArCont.text.trim(),
      'duration_min': durationCont.text.trim(),
      'duration': durationCont.text.trim(),
      'time_slot': durationCont.text.trim(),
      'clinic_id': selectedClinic.value.id,
      'vendor_id': clinicVendorId,
      'charges': priceCont.text.trim(),
      'price': priceCont.text.trim(),
      'type': selectedType.value,
      'description': descriptionCont.text.trim(),
      'description_ar': descriptionArCont.text.trim(),
      'status': status.value.getIntBool(),
    };

    File? uploadFile;
    if (imageFile.value.path.isNotEmpty) {
      if (await imageFile.value.exists()) {
        uploadFile = imageFile.value;
      } else {
        // Cache file was evicted by the OS between picking and submitting.
        imageFile(File(""));
        toast(locale.value.pleaseSelectAServiceImage);
        return;
      }
    }

    isLoading(true);
    try {
      await ServiceFormApis.saveService(
        request: request,
        imageFile: uploadFile,
        isEdit: isEdit.value,
        serviceId: isEdit.value && !serviceData.value.id.isNegative ? serviceData.value.id : null,
        onSuccess: (_) {
          toast(isEdit.value ? locale.value.serviceUpdatedSuccessfully : locale.value.serviceCreatedSuccessfully);
        },
      );
      Get.back(result: true);
    } catch (e) {
      toast(e.toString());
    } finally {
      isLoading(false);
    }
  }

  Future<void> _handleGalleryClick() async {
    Get.back();
    pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      serviceImage('');
      imageFile(File(pickedFile!.path));
    }
  }

  Future<void> _handleCameraClick() async {
    Get.back();
    pickedFile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (pickedFile != null) {
      serviceImage('');
      imageFile(File(pickedFile!.path));
    }
  }

  void showBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      backgroundColor: context.cardColor,
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SettingItemWidget(
              title: locale.value.gallery,
              leading: const Icon(Icons.image, color: appColorPrimary),
              onTap: () async {
                _handleGalleryClick();
              },
            ),
            SettingItemWidget(
              title: locale.value.camera,
              leading: const Icon(Icons.camera, color: appColorPrimary),
              onTap: () {
                _handleCameraClick();
              },
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
          ],
        ).paddingAll(16.0);
      },
    );
  }

  @override
  void onClose() {
    clinicSearchStream.close();
    super.onClose();
  }
}
