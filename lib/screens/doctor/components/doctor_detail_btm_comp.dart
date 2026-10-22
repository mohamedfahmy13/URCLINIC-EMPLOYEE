import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:kivicare_clinic_admin/screens/doctor/doctor_session/doctor_session_screen.dart';
import 'package:kivicare_clinic_admin/screens/service/all_service_list_screen.dart';
import '../../../generated/assets.dart';
import '../../../main.dart';
import '../../../utils/app_common.dart';
import '../../../utils/colors.dart';
import '../../../utils/common_base.dart';
import '../../../utils/constants.dart';
import '../doctor_about_screen.dart';
import '../doctor_detail_controller.dart';
import '../doctor_qualification_screen.dart';
import '../doctor_session/doctor_schedule_screen.dart';

class DoctorDetailBtmComp extends StatelessWidget {
  DoctorDetailBtmComp({
    super.key,
  });

  final DoctorDetailController doctorDetailCont =
      Get.put(DoctorDetailController());

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: Get.width,
      child: Column(
        children: [
          SettingItemWidget(
            title: locale.value.aboutMyself,
            decoration: boxDecorationDefault(color: context.cardColor),
            subTitle: locale.value.experienceSpecializationContactInfo,
            splashColor: transparentColor,
            onTap: () {
              Get.to(
                () => DoctorAboutScreen(
                  doctorData: doctorDetailCont.doctorDetails.value,
                ),
              );
            },
            titleTextStyle: boldTextStyle(size: 14),
            leading: commonLeadingWid(
                imgPath: Assets.iconsIcInfo, color: context.themePrimary),
            trailing: const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: darkGray),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          ).paddingTop(16),
          SettingItemWidget(
            title: loginUserData.value.userRole
                    .contains(EmployeeKeyConst.receptionist)
                ? locale.value.scheduleManage
                : locale.value.sessions,
            decoration: boxDecorationDefault(color: context.cardColor),
            subTitle: loginUserData.value.userRole
                    .contains(EmployeeKeyConst.receptionist)
                ? locale.value.scheduleHint
                : locale.value.doctorSessionsInformation,
            splashColor: transparentColor,
            onTap: () {
              final roles = loginUserData.value.userRole;
              final doctor = doctorDetailCont.doctorDetails.value;
              if (roles.contains(EmployeeKeyConst.receptionist) ||
                  roles.contains(EmployeeKeyConst.vendor) ||
                  (roles.contains(EmployeeKeyConst.doctor) &&
                      doctor.doctorId == loginUserData.value.id)) {
                final clinicId = selectedAppClinic.value.id > 0
                    ? selectedAppClinic.value.id
                    : loginUserData.value.clinicId;
                // Receptionists use the clinic resolved by the authenticated API.
                Get.to(() => DoctorScheduleScreen(
                      doctorId: doctor.doctorId,
                      doctorName: doctor.fullName,
                      clinicId: roles.contains(EmployeeKeyConst.receptionist)
                          ? null
                          : clinicId,
                    ));
              } else {
                Get.to(() => DoctorSessionScreen(), arguments: doctor);
              }
            },
            titleTextStyle: boldTextStyle(size: 14),
            leading: commonLeadingWid(
                imgPath: Assets.iconsIcClock, color: context.themePrimary),
            trailing: const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: darkGray),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          ).paddingTop(16),
          SettingItemWidget(
            title: locale.value.services,
            decoration: boxDecorationDefault(color: context.cardColor),
            subTitle: doctorDetailCont.doctorDetails.value.services.isEmpty
                ? locale.value.noServicesTillNow
                : "${locale.value.total} ${doctorDetailCont.doctorDetails.value.services.length} ${locale.value.serviceAvaliable}",
            splashColor: transparentColor,
            onTap: () {
              if (doctorDetailCont.doctorDetails.value.services.isEmpty) {
                toast(locale.value.oopsThisDoctorDoesntHaveAnyServicesYet);
              } else {
                Get.to(() => AllServicesScreen(),
                    arguments: doctorDetailCont.doctorDetails.value);
              }
            },
            titleTextStyle: boldTextStyle(size: 14),
            leading: commonLeadingWid(
                imgPath: Assets.iconsIcServices, color: context.themePrimary),
            trailing: const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: darkGray),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          ).paddingTop(16).visible(!loginUserData.value.userRole
              .contains(EmployeeKeyConst.receptionist)),
          SettingItemWidget(
            title: locale.value.qualification,
            decoration: boxDecorationDefault(color: context.cardColor),
            subTitle:
                doctorDetailCont.doctorDetails.value.qualifications.isEmpty
                    ? locale.value.qualificationDetailIsNotAvilable
                    : locale.value.qualificationInDetail,
            splashColor: transparentColor,
            onTap: () {
              if (doctorDetailCont.doctorDetails.value.qualifications.isEmpty) {
                toast(locale.value.qualificationDetailIsNotAvilable);
              } else {
                Get.to(() => QualificationScreen(
                    doctorData: doctorDetailCont.doctorDetails.value));
              }
            },
            titleTextStyle: boldTextStyle(size: 14),
            leading: commonLeadingWid(
                imgPath: Assets.iconsIcQualification, color: context.themePrimary),
            trailing: const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: darkGray),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          ).paddingTop(16),
        ],
      ),
    );
  }
}
