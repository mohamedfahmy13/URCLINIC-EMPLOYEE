import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:kivicare_clinic_admin/main.dart';
import '../../components/app_scaffold.dart';
import '../../components/loader_widget.dart';
import '../../utils/empty_error_state_widget.dart';
import '../Encounter/add_encounter/model/patient_model.dart';
import 'add_patient/add_patient_screen.dart';
import 'all_patient_list_controller.dart';
import 'components/patient_card.dart';
import 'patient_detail_screen.dart';

class AllPatientList extends StatelessWidget {
  AllPatientList({super.key});

  final AllPatientListcontroller allPatientsCont = Get.put(AllPatientListcontroller());

  @override
  Widget build(BuildContext context) {
    return AppScaffoldNew(
      appBartitleText: locale.value.patients,
      appBarVerticalSize: Get.height * 0.12,
      isLoading: allPatientsCont.isLoading,
      actions: [
        IconButton(
          tooltip: locale.value.addPatient,
          onPressed: () {
            Get.to(() => AddPatientScreen())?.then((value) {
              if (value is PatientModel) allPatientsCont.refreshList();
            });
          },
          icon: const Icon(Icons.add_circle_outline_rounded, size: 28, color: Colors.white),
        ).paddingOnly(right: 8),
      ],
      body: SnapHelperWidget(
        future: allPatientsCont.patientFuture.value,
        loadingWidget: allPatientsCont.isLoading.value ? const Offstage() : const LoaderWidget(),
        errorBuilder: (error) {
          return NoDataWidget(
            title: error,
            retryText: locale.value.reload,
            imageWidget: const ErrorStateWidget(),
            onRetry: () {
              allPatientsCont.patientPage(1);
              allPatientsCont.getPatientList();
            },
          );
        },
        onSuccess: (res) {
          return Obx(
            () => AnimatedListView(
              shrinkWrap: true,
              itemCount: allPatientsCont.patientList.length,
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              emptyWidget: NoDataWidget(
                title: locale.value.noPatientsFound,
                subTitle: locale.value.oppsNoPatientsFoundAtMomentTryAgainLater,
                imageWidget: const EmptyStateWidget(),
              ).paddingSymmetric(horizontal: 32).visible(!allPatientsCont.isLoading.value),
              onSwipeRefresh: () async {
                allPatientsCont.patientPage(1);
                return allPatientsCont.getPatientList(showloader: false);
              },
              onNextPage: () async {
                if (!allPatientsCont.isPatientLastPage.value) {
                  allPatientsCont.patientPage++;
                  allPatientsCont.getPatientList();
                }
              },
              itemBuilder: (ctx, index) {
                return GestureDetector(
                  onTap: () {
                    Get.to(() => PatientDetailScreen(), arguments: allPatientsCont.patientList[index])?.then((value) {
                      if (value == true) allPatientsCont.refreshList();
                    });
                  },
                  child: PatientCardWid(patient: allPatientsCont.patientList[index]).paddingBottom(16),
                );
              },
            ),
          );
        },
      ).paddingSymmetric(vertical: 16),
    );
  }
}
