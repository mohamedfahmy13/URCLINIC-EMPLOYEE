import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:kivicare_clinic_admin/screens/doctor/components/doctor_card.dart';
import 'package:kivicare_clinic_admin/screens/doctor/components/search_doctor_widget.dart';
import '../../api/doctor_apis.dart';
import '../../../components/app_scaffold.dart';
import 'package:get/get.dart';
import '../../components/loader_widget.dart';
import '../../main.dart';
import '../../utils/app_common.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../../utils/empty_error_state_widget.dart';
import 'add_doctor/add_doctor_form.dart';
import 'model/doctor_list_res.dart';
import 'doctor_detail_screen.dart';
import 'doctor_list_controller.dart';

enum _DoctorAction { edit, delete }

class DoctorsListScreen extends StatelessWidget {
  DoctorsListScreen({super.key});
  final DoctorListController doctorsListCont = Get.put(DoctorListController());

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AppScaffoldNew(
        appBartitleText: locale.value.doctors,
        scaffoldBackgroundColor: context.scaffoldBackgroundColor,
        appBarVerticalSize: Get.height * 0.12,
        isLoading: doctorsListCont.isLoading,
        actions: [
          IconButton(
            onPressed: _handleAddDoctor,
            icon: const Icon(Icons.add_circle_outline_rounded,
                size: 28, color: white),
          ).paddingOnly(right: 8).visible(canManageDoctors),
        ],
        body: RefreshIndicator(
          onRefresh: () async {
            doctorsListCont.page(1);
            return doctorsListCont.getDoctors();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(
                () => SearchDoctorWidget(
                  doctorListCont: doctorsListCont,
                  onFieldSubmitted: (p0) {
                    hideKeyboard(context);
                  },
                )
                    .paddingSymmetric(horizontal: 16)
                    .paddingTop(16)
                    .visible(doctorsListCont.doctors.length > 6),
              ),
              Obx(
                () => SnapHelperWidget(
                  future: doctorsListCont.doctorsFuture.value,
                  errorBuilder: (error) {
                    return NoDataWidget(
                      title: error,
                      retryText: locale.value.reload,
                      imageWidget: const ErrorStateWidget(),
                      onRetry: () {
                        doctorsListCont.page(1);
                        doctorsListCont.getDoctors();
                      },
                    ).paddingSymmetric(horizontal: 32);
                  },
                  loadingWidget: doctorsListCont.isLoading.value
                      ? const Offstage()
                      : const LoaderWidget(),
                  onSuccess: (p0) {
                    if (doctorsListCont.doctors.isEmpty) {
                      return NoDataWidget(
                        title: locale.value.noDoctorsFound,
                        imageWidget: const EmptyStateWidget(),
                      )
                          .paddingSymmetric(horizontal: 32)
                          .paddingBottom(Get.height * 0.15)
                          .visible(!doctorsListCont.isLoading.value);
                    } else {
                      return AnimatedScrollView(
                        children: [
                          AnimatedWrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: List.generate(
                              doctorsListCont.doctors.length,
                              (index) {
                                return Obx(() {
                                  final doctor = doctorsListCont.doctors[index];
                                  // Orphaned rows (deleted user) come back with no doctor_id.
                                  if (doctor.doctorId <= 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          Get.to(() => DoctorDetailScreen(),
                                              arguments: doctor);
                                        },
                                        child: DoctorCard(doctor: doctor),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: PopupMenuButton<_DoctorAction>(
                                          enabled: canManageDoctors,
                                          tooltip: '',
                                          icon: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: boxDecorationDefault(
                                              color: context.cardColor
                                                  .withValues(alpha: 0.95),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(Icons.more_vert,
                                                size: 20,
                                                color: context.themePrimary),
                                          ),
                                          onSelected: (action) {
                                            if (action == _DoctorAction.edit) {
                                              _handleEditDoctor(doctor);
                                            } else {
                                              handleDeleteDoctorClick(
                                                  context: context,
                                                  doctor: doctor,
                                                  index: index);
                                            }
                                          },
                                          itemBuilder: (context) {
                                            if (!canManageDoctors) {
                                              return const [];
                                            }
                                            return [
                                              PopupMenuItem<_DoctorAction>(
                                                value: _DoctorAction.edit,
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                        Icons.edit_outlined,
                                                        size: 18,
                                                        color: context.themePrimary),
                                                    8.width,
                                                    Text(locale.value.edit,
                                                        style: primaryTextStyle(
                                                            size: 13)),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem<_DoctorAction>(
                                                value: _DoctorAction.delete,
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        size: 18,
                                                        color: redColor),
                                                    8.width,
                                                    Text(locale.value.delete,
                                                        style: primaryTextStyle(
                                                            size: 13)),
                                                  ],
                                                ),
                                              ),
                                            ];
                                          },
                                        ).visible(canManageDoctors),
                                      ),
                                    ],
                                  );
                                });
                              },
                            ),
                          ),
                        ],
                        onNextPage: () async {
                          if (!doctorsListCont.isLastPage.value) {
                            doctorsListCont
                                .page(doctorsListCont.page.value + 1);
                            doctorsListCont.getDoctors();
                          }
                        },
                      ).paddingSymmetric(horizontal: 16);
                    }
                  },
                ),
              ).paddingTop(16).expand(),
            ],
          ).makeRefreshable,
        ),
      ),
    );
  }

  bool get canManageDoctors =>
      loginUserData.value.userRole.contains(EmployeeKeyConst.receptionist) ||
      loginUserData.value.userRole.contains(EmployeeKeyConst.vendor);

  Future<void> _handleAddDoctor() async {
    await Get.to(() => AddDoctorForm())?.then((value) {
      if (value == true) {
        doctorsListCont.page(1);
        doctorsListCont.getDoctors();
      }
    });
  }

  Future<void> _handleEditDoctor(Doctor doctor) async {
    await Get.to(() => AddDoctorForm(isEdit: true), arguments: doctor)
        ?.then((value) {
      if (value == true) {
        doctorsListCont.page(1);
        doctorsListCont.getDoctors();
      }
    });
  }

  Future<void> handleDeleteDoctorClick({
    required BuildContext context,
    required Doctor doctor,
    required int index,
  }) async {
    showConfirmDialogCustom(
      context,
      primaryColor: appColorPrimary,
      title: locale.value.areYouSureYouWantToDeleteThisDoctor,
      positiveText: locale.value.delete,
      negativeText: locale.value.cancel,
      onAccept: (ctx) async {
        doctorsListCont.isLoading(true);
        DoctorApis.deleteDoctor(doctorId: doctor.doctorId).then((value) {
          doctorsListCont.doctors.removeAt(index);
          toast(value.message.trim().isEmpty
              ? locale.value.doctorDeleteSuccessfully
              : value.message.trim());
        }).catchError((e) {
          toast(e.toString());
        }).whenComplete(() {
          doctorsListCont.isLoading(false);
        });
      },
    );
  }
}
