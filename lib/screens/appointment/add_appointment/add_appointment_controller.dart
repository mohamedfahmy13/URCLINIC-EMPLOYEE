import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../../api/core_apis.dart';
import '../../../main.dart';
import '../../../utils/app_common.dart';
import '../../../utils/common_base.dart';
import '../../../utils/constants.dart';
import '../../Encounter/add_encounter/model/patient_model.dart';
import '../../auth/model/login_response.dart';
import '../../clinic/model/clinics_res_model.dart';
import '../../dashboard/dashboard_controller.dart';
import '../../dashboard/dashboard_screen.dart';
import '../../doctor/model/doctor_list_res.dart';
import '../../service/model/service_list_model.dart';
import '../appointments_controller.dart';
import '../model/appointments_res_model.dart';
import '../model/save_payment_req.dart';
import 'booking_success_screen.dart';

class AddAppointmentController extends GetxController {
  TextEditingController clinicCenterCont = TextEditingController();
  TextEditingController servicesCont = TextEditingController();
  TextEditingController doctorCont = TextEditingController();
  TextEditingController medicalReportCont = TextEditingController();

  // Doctors of the receptionist's clinic, and the services the chosen doctor offers there.
  RxList<Doctor> doctorList = RxList();
  RxBool isDoctorLoading = false.obs;
  RxList<ServiceElement> doctorServices = RxList();
  RxBool isServiceLoading = false.obs;

  FocusNode clinicCenterFocus = FocusNode();
  FocusNode servicesFocus = FocusNode();
  FocusNode medicalHistoryFocus = FocusNode();

  RxList<PlatformFile> medicalReportFiles = RxList();

  Rx<ClinicData> selectedClinic = ClinicData().obs;

  Rx<ServiceElement> selectedService = ServiceElement(status: false.obs).obs;

  TextEditingController searchCont = TextEditingController();
  TextEditingController patientCont = TextEditingController();

  FocusNode patientFocus = FocusNode();

  RxBool isLoading = false.obs;

  RxBool saveBtnVisible = false.obs;

  final GlobalKey<FormState> addAppointmentformKey = GlobalKey<FormState>();

  final ScrollController scrollController = ScrollController();

  Rx<Doctor> doctorData = Doctor().obs;
  Rx<ClinicData> clinicData = ClinicData().obs;
  Rx<AppointmentData> appointment = AppointmentData().obs;

  //Date & Timeslot
  Rx<Future<RxList<String>>> slotsFuture = Future(() => RxList<String>()).obs;
  RxList<String> slots = RxList();
  RxString selectedDate = DateTime.now().formatDateYYYYmmdd().obs;
  RxString selectedSlot = "".obs;

  //Patient
  RxList<PatientModel> patientList = RxList();
  RxBool isPatientLastPage = false.obs;
  RxInt patientPage = 1.obs;
  Rx<PatientModel> selectPatient = PatientModel().obs;
  RxString searchPatient = "".obs;

  //Error Patient
  RxBool hasErrorFetchingPatient = false.obs;
  RxString errorMessagePatient = "".obs;

  //Book for Other Patient
  Rx<Future<RxList<UserData>>> otherPatientListFuture = Future(() => RxList<UserData>()).obs;
  RxList<UserData> otherPatientList = <UserData>[].obs;
  RxInt page = 1.obs;
  RxBool isLastPage = false.obs;
  Rx<UserData> selectedMember = UserData().obs;

  bool get isDoctorUser => loginUserData.value.userRole.contains(EmployeeKeyConst.doctor);

  @override
  Future<void> onInit() async {
    if (Get.arguments is Doctor) {
      doctorData(Get.arguments as Doctor);
      doctorCont.text = doctorData.value.fullName;
    } else if (Get.arguments is PatientModel) {
      choosePatient(Get.arguments as PatientModel);
    }
    getPatientList();
    if (!isDoctorUser) getDoctorList();
    if (!doctorData.value.doctorId.isNegative) getDoctorServices();
    super.onInit();
  }

  /// Select the patient to book for and load their family members.
  void choosePatient(PatientModel patient) {
    selectPatient(patient);
    patientCont.text = patient.fullName;
    selectedMember(UserData());
    otherPatientList.clear();
    getOtherPatientList(patientId: patient.id.toString());
  }

  Future<void> getDoctorList() async {
    isDoctorLoading(true);
    try {
      final List<Doctor> doctors = [];
      await CoreServiceApis.getDoctors(page: 1, perPage: 100, doctors: doctors, clinicId: getClinicId);
      doctorList(doctors.where((doctor) => doctor.doctorId > 0).toList());
    } catch (e) {
      log('getDoctorList err: $e');
      toast(e.toString());
    } finally {
      isDoctorLoading(false);
    }
  }

  /// A new doctor means a new service list and new slots.
  void selectDoctor(Doctor doctor) {
    doctorData(doctor);
    doctorCont.text = doctor.fullName;
    selectedService(ServiceElement(status: false.obs));
    servicesCont.clear();
    slots.clear();
    selectedSlot('');
    saveBtnVisible(false);
    getDoctorServices();
  }

  /// Only services this doctor offers at this clinic can be booked (the backend checks it too).
  Future<void> getDoctorServices() async {
    isServiceLoading(true);
    try {
      final List<ServiceElement> services = [];
      await CoreServiceApis.getServiceList(perPage: 100, serviceList: services, clinicId: getClinicId, doctorId: doctorData.value.doctorId);
      doctorServices(services
          .where((service) => service.status.value && service.assignDoctor.any((a) => a.doctorId == doctorData.value.doctorId && a.clinicId == getClinicId))
          .toList());
    } catch (e) {
      doctorServices.clear();
      log('getDoctorServices err: $e');
      toast(e.toString());
    } finally {
      isServiceLoading(false);
    }
  }

  void selectService(ServiceElement service) {
    selectedService(service);
    servicesCont.text = service.name;
    selectedSlot('');
    saveBtnVisible(false);
    getTimeSlot();
  }

  bool _validateBooking() {
    if (selectPatient.value.id.isNegative) {
      toast(locale.value.pleaseSelectPatient);
      return false;
    }
    if (doctorData.value.doctorId.isNegative) {
      toast(locale.value.pleaseSelectDoctor);
      return false;
    }
    if (selectedService.value.id.isNegative) {
      toast(locale.value.pleaseSelectService);
      return false;
    }
    if (selectedSlot.value.isEmpty) {
      toast(locale.value.pleaseSelectTimeSlot);
      return false;
    }
    return true;
  }

  Future<void> saveBooking() async {
    if (isLoading.value || !_validateBooking()) return;
    hideKeyBoardWithoutContext();
    isLoading(true);

    final Map<String, dynamic> request = {
      "clinic_id": getClinicId.toString(),
      "service_id": selectedService.value.id.toString(),
      "doctor_id": doctorData.value.doctorId.toString(),
      "user_id": selectPatient.value.id.toString(),
      "appointment_date": selectedDate.value.trim(),
      "appointment_time": selectedSlot.value,
      "appointment_extra_info": medicalReportCont.text.trim(),
      if (selectedMember.value.id > 0) "otherpatient_id": selectedMember.value.id.toString(),
    };

    try {
      final int appointmentId = await CoreServiceApis.bookAppointment(request: request, files: medicalReportFiles);

      // Walk-ins pay cash at checkout: record the unpaid cash transaction billing expects.
      try {
        await CoreServiceApis.savePayment(
          request: SavePaymentReq(
            id: appointmentId,
            transactionType: PaymentMethods.PAYMENT_METHOD_CASH,
            taxPercentage: appConfigs.value.exclusiveTaxList,
            paymentStatus: 0,
            advancePaymentAmount: appointment.value.advancePaymentAmount,
            advancePaymentStatus: appointment.value.advancePaymentStatus,
          ).toJson(),
        );
      } catch (e) {
        log('savePayment after booking err: $e');
      }

      await onSuccess();
    } catch (e) {
      isLoading(false);
      toast(e.toString(), print: true);
      // The slot may have just been taken: reload so the receptionist can pick another one.
      getTimeSlot(showLoader: false);
    }
  }

  Future<void> onSuccess() async {
    isLoading(false);
    reLoadBookingsOnDashboard();
    await Future.delayed(const Duration(milliseconds: 300));
    Get.offUntil(
      GetPageRoute(
        page: () => BookingSuccessScreen(),
        binding: BindingsBuilder(() {
          setStatusBarColor(transparentColor, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.dark);
        }),
      ),
      (route) => route.isFirst || route.settings.name == '/$DashboardScreen',
    );
  }

  void reLoadBookingsOnDashboard() {
    try {
      final AppointmentsController aCont = Get.find();
      aCont.getAppointmentList();
    } catch (e) {
      log('E: $e');
    }
    try {
      final DashboardController dashboardController = Get.find();
      dashboardController.currentIndex(1);
      dashboardController.reloadBottomTabs();
    } catch (e) {
      log('E: $e');
    }
  }

  Future<void> getTimeSlot({bool showLoader = true}) async {
    if (showLoader) {
      isLoading(true);
    }

    /// Get Time Slots Api Call
    await slotsFuture(
      CoreServiceApis.getTimeSlots(
        slots: slots,
        date: selectedDate.value,
        serviceId: selectedService.value.id,
        clinicId: getClinicId,
        doctorId: doctorData.value.doctorId,
      ),
    ).then((value) {
      log('value.length ==> ${value.length}');
      // Drop a selection that is no longer offered (e.g. booked meanwhile).
      if (selectedSlot.value.isNotEmpty && !slots.contains(selectedSlot.value)) {
        selectedSlot('');
        onDateTimeChange();
      }
    }).catchError((e) {
      isLoading(false);
      log("getTimeSlots error $e");
    }).whenComplete(() => isLoading(false));
  }

  /// Staff always book into their own (selected) clinic.
  int get getClinicId => selectedAppClinic.value.id;

  void onDateTimeChange() {
    final appointmentDateTime = "${selectedDate.value} ${selectedSlot.value}";
    if (appointmentDateTime.isValidDateTime) {
      saveBtnVisible(true);
    } else {
      saveBtnVisible(false);
    }
  }

  Future<void> getPatientList({bool showloader = true}) async {
    if (showloader) {
      isLoading(true);
    }
    // Patients of this clinic only (the backend scopes the list to the receptionist's clinic).
    await CoreServiceApis.getPatientsList(
      patientsList: patientList,
      page: patientPage.value,
      search: searchPatient.value,
      lastPageCallBack: (p0) {
        isPatientLastPage(p0);
      },
    ).then((value) {
      hasErrorFetchingPatient(false);
    }).catchError((e) {
      hasErrorFetchingPatient(true);
      errorMessagePatient(e.toString());
      log("getPatientsList err: $e");
    }).whenComplete(() => isLoading(false));
  }

  Future<void> onRefresh({required String patientId}) async {
    page(1);
    await getOtherPatientList(patientId: patientId, showLoader: false);
  }

  Future<void> getOtherPatientList({bool showLoader = true, required String patientId}) async {
    if (showLoader) isLoading(true);

    await otherPatientListFuture(
      CoreServiceApis.otherMemberPatientList(
        patientId: patientId,
        page: page.value,
        memberList: otherPatientList,
        lastPageCallBack: (p0) {
          isLastPage(p0);
        },
      ),
    ).then((value) {
      log('value.length ==> ${value.length}');
    }).catchError((e) {
      isLoading(false);
      log("getOtherPatientList Err : $e");
    }).whenComplete(() => isLoading(false));
  }

  //----------------------------------------Price Calculation-----------------------------------
  AssignDoctor get finalAssignDoctor => selectedService.value.assignDoctor.firstWhere(
        (element) => element.doctorId == doctorData.value.doctorId && element.clinicId == getClinicId,
        orElse: () => AssignDoctor(
          priceDetail: PriceDetail(
            servicePrice: selectedService.value.charges,
            serviceAmount: selectedService.value.charges,
            discountAmount: selectedService.value.discountAmount,
            discountType: selectedService.value.discountType,
            discountValue: selectedService.value.discountValue,
            totalAmount: selectedService.value.payableAmount,
            duration: selectedService.value.duration,
          ),
        ),
      );

  double get fixedExclusiveTaxAmount => appConfigs.value.taxData.where((element) => (element.taxScope == TaxType.exclusiveTax) && (element.type.toLowerCase().contains(TaxType.FIXED.toLowerCase()))).sumByDouble((p0) => p0.value.validate());

  double get percentExclusiveTaxAmount => appConfigs.value.taxData.where((element) {
        return (element.taxScope == TaxType.exclusiveTax) && (element.type.toLowerCase().contains(TaxType.PERCENT.toLowerCase()));
      }).sumByDouble((p0) {
        return (selectedService.value.assignDoctor.isNotEmpty ? finalAssignDoctor.priceDetail.serviceAmount * p0.value.validate() : selectedService.value.payableAmount * p0.value.validate()) / 100;
      });

  num get totalExclusiveTax => (fixedExclusiveTaxAmount + percentExclusiveTaxAmount).toStringAsFixed(Constants.DECIMAL_POINT).toDouble();

  num get totalAmount => (selectedService.value.assignDoctor.isNotEmpty ? (finalAssignDoctor.priceDetail.totalAmount) : (selectedService.value.payableAmount + totalExclusiveTax));

  num get advancePayableAmount => (totalAmount * selectedService.value.advancePaymentAmount) / 100;

  num get remainingAmountAfterService => totalAmount - advancePayableAmount;

  Future<void> handleFilesPickerClick() async {
    isLoading(true);

    try {
      final pickedFiles = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        // Same types the backend accepts for booking attachments.
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: true,
      );

      if (pickedFiles != null && pickedFiles.files.isNotEmpty) {
        Set<String> existingFiles = medicalReportFiles.map((file) => file.name.trim().toLowerCase()).toSet();

        for (final file in pickedFiles.files) {
          if (file.path != null) {
            final fileSize = file.size;
            if (fileSize > 5 * 1024 * 1024) {
              toast(locale.value.selectedFileShouldBeLessThan5MB);
              continue;
            }

            if (!existingFiles.contains(file.name.trim().toLowerCase())) {
              medicalReportFiles.add(file);
            }
          }
        }
      } else {
        toast(locale.value.noFileSelected);
      }
    } catch (e) {
      toast('File picking failed: $e');
    } finally {
      isLoading(false);
    }
  }
}
