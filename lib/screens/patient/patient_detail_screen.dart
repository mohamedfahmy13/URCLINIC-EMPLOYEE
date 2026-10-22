import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:kivicare_clinic_admin/screens/appointment/appointments_screen.dart';
import 'package:kivicare_clinic_admin/utils/common_base.dart';
import '../../components/app_scaffold.dart';
import '../../components/cached_image_widget.dart';
import '../../generated/assets.dart';
import '../../main.dart';
import '../../utils/colors.dart';
import '../Encounter/add_encounter/model/patient_model.dart';
import '../appointment/appointments_controller.dart';
import 'add_patient/add_patient_controller.dart';
import 'add_patient/add_patient_screen.dart';
import 'all_patient_list_controller.dart';
import 'components/patient_info_card.dart';
import 'model/patient_argument_model.dart';
import 'patient_detail_controller.dart';

class PatientDetailScreen extends StatelessWidget {
  PatientDetailScreen({super.key});

  final PatientDetailController patientDetailCont = Get.put(PatientDetailController());

  @override
  Widget build(BuildContext context) {
    return AppScaffoldNew(
      appBartitleText: locale.value.patientDetail,
      appBarVerticalSize: Get.height * 0.12,
      actions: [
        IconButton(
          tooltip: locale.value.editPatient,
          onPressed: _editPatient,
          icon: const Icon(Icons.edit_outlined, size: 22, color: Colors.white),
        ).paddingOnly(right: 8),
      ],
      // Rebuilt after an edit so the new details show without reopening the screen.
      body: Obx(() => AnimatedScrollView(
        children: [
          Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CachedImageWidget(
                    url: patientDetailCont.patientModel.value.profileImage,
                    fit: BoxFit.cover,
                    width: Get.width,
                    topLeftRadius: (defaultRadius * 2).toInt(),
                    topRightRadius: (defaultRadius * 2).toInt(),
                  ),
                  Positioned(
                    bottom: -sizeOfInfoCard * 0.6,
                    width: Get.width,
                    child: PatientInfoCard(sizeOfInfoCard: sizeOfInfoCard, patientDetailCont: patientDetailCont),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: sizeOfInfoCard * 0.6 + 24),
          SettingItemWidget(
            title: locale.value.appointments,
            decoration: boxDecorationDefault(),
            subTitle: "${locale.value.total} ${patientDetailCont.patientModel.value.totalAppointments} ${locale.value.appointmentsTillNow}",
            splashColor: transparentColor,
            onTap: () {
              Get.to(
                () => AppointmentsScreen(),
                arguments: PatientArgumentModel(patientModel: patientDetailCont.patientModel.value, isFromPatientDetail: true),
                binding: BindingsBuilder(
                  () {
                    try {
                      final AppointmentsController aCont = Get.find();
                      aCont.selectedPatient(patientDetailCont.patientModel.value);
                      aCont.getAppointmentList();
                    } catch (e) {
                      log('aCont = Get.find() Err: $e');
                    }
                  },
                ),
              )?.then((res) {
                try {
                  final AppointmentsController aCont = Get.find();
                  aCont.patientDetailArgument(PatientArgumentModel(patientModel: PatientModel()));
                  aCont.selectedPatient(PatientModel());
                  aCont.getAppointmentList();
                } catch (e) {
                  log('aCont = Get.find() Err: $e');
                }
              });
            },
            titleTextStyle: boldTextStyle(size: 14),
            leading: commonLeadingWid(imgPath: Assets.iconsIcCalendarplus, color: appColorSecondary),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: darkGray),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          ).paddingSymmetric(horizontal: 24),
        ],
      )),
    );
  }

  void _editPatient() {
    if (Get.isRegistered<AddPatientController>()) Get.delete<AddPatientController>();
    Get.to(() => AddPatientScreen(), arguments: patientDetailCont.patientModel.value)?.then((value) {
      if (value is PatientModel) {
        // The save response has no appointment count; keep the one already shown.
        value.totalAppointments = patientDetailCont.patientModel.value.totalAppointments;
        patientDetailCont.patientModel(value);
        try {
          Get.find<AllPatientListcontroller>().refreshList();
        } catch (e) {
          log('AllPatientListcontroller not found: $e');
        }
      }
    });
  }

  double get sizeOfInfoCard => Get.height * 0.13;
}
