import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kivicare_clinic_admin/utils/colors.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../../components/app_primary_widget.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/bottom_selection_widget.dart';
import '../../../components/cached_image_widget.dart';
import '../../../components/chat_gpt_loder.dart';
import '../../../generated/assets.dart';
import '../../../main.dart';
import '../../../utils/app_common.dart';
import '../../../utils/common_base.dart';
import '../../../utils/constants.dart';
import '../../clinic/model/clinics_res_model.dart';
import 'add_service_controller.dart';

class AddServiceForm extends StatelessWidget {
  final bool isEdit;

  AddServiceForm({super.key, this.isEdit = false});

  final CreateServiceController c = Get.put(CreateServiceController());

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AppScaffoldNew(
        appBartitleText: c.isEdit.value ? locale.value.editService : locale.value.createService,
        isLoading: c.isLoading,
        body: AnimatedScrollView(
          controller: c.scrollController,
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 60, top: 16),
          children: [
            Form(
              key: c.addClinicformKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image
                  Text(locale.value.serviceImage, style: boldTextStyle(size: 16)),
                  6.height,
                  Text(
                    locale.value.onlyJpegJpgPngAllowed,
                    style: secondaryTextStyle(size: 11, color: secondaryTextColor),
                  ),
                  12.height,
                  _buildImagePicker(context),
                  16.height,

                  // Name
                  _label(locale.value.name, required: true),
                  6.height,
                  AppTextField(
                    textStyle: primaryTextStyle(size: 12),
                    controller: c.serviceCont,
                    focus: c.serviceNameFocus,
                    nextFocus: c.serviceNameArFocus,
                    textFieldType: TextFieldType.NAME,
                    decoration: inputDecoration(
                      context,
                      hintText: locale.value.name,
                      fillColor: context.cardColor,
                      filled: true,
                    ),
                  ),
                  16.height,

                  // Name (Arabic)
                  _label(locale.value.nameInArabic, required: true),
                  6.height,
                  AppTextField(
                    textStyle: primaryTextStyle(size: 12),
                    controller: c.serviceArCont,
                    focus: c.serviceNameArFocus,
                    nextFocus: c.serviceDurationFocus,
                    textFieldType: TextFieldType.NAME,
                    textAlign: TextAlign.right,
                    decoration: inputDecoration(
                      context,
                      hintText: locale.value.nameInArabicHint,
                      fillColor: context.cardColor,
                      filled: true,
                    ),
                  ),
                  16.height,

                  // Time slot
                  _label(locale.value.serviceDurationMin, required: true),
                  6.height,
                  AppTextField(
                    textStyle: primaryTextStyle(size: 12),
                    controller: c.durationCont,
                    focus: c.serviceDurationFocus,
                    nextFocus: c.defaultPriceFocus,
                    textFieldType: TextFieldType.NUMBER,
                    decoration: inputDecoration(
                      context,
                      hintText: locale.value.serviceDurationMin,
                      fillColor: context.cardColor,
                      filled: true,
                    ),
                  ),
                  16.height,

                  // Clinic
                  _label(locale.value.clinic, required: true),
                  6.height,
                  AppTextField(
                    textStyle: primaryTextStyle(size: 12),
                    controller: c.clinicCont,
                    textFieldType: TextFieldType.NAME,
                    readOnly: true,
                    // A receptionist's services always belong to their own clinic.
                    onTap: c.isReceptionist
                        ? null
                        : () {
                            hideKeyboard(context);
                            c.getClinics();
                            _openClinicSheet(context);
                          },
                    decoration: inputDecoration(
                      context,
                      hintText: locale.value.selectClinic,
                      fillColor: context.cardColor,
                      filled: true,
                      suffixIcon: c.isReceptionist ? null : Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: darkGray.withValues(alpha: 0.5)),
                    ),
                  ),
                  16.height,

                  // Default Price
                  _label(locale.value.defaultPrice, required: true),
                  6.height,
                  AppTextField(
                    textStyle: primaryTextStyle(size: 12),
                    controller: c.priceCont,
                    textFieldType: TextFieldType.NUMBER,
                    focus: c.defaultPriceFocus,
                    decoration: inputDecoration(
                      context,
                      hintText: locale.value.defaultPrice,
                      fillColor: context.cardColor,
                      filled: true,
                    ),
                  ),
                  16.height,

                  // Type
                  _label(locale.value.serviceType, required: true),
                  6.height,
                  AppTextField(
                    textStyle: primaryTextStyle(size: 12),
                    controller: c.typeCont,
                    textFieldType: TextFieldType.NAME,
                    readOnly: true,
                    onTap: () {
                      hideKeyboard(context);
                      _openTypeSheet(context);
                    },
                    decoration: inputDecoration(
                      context,
                      hintText: locale.value.selectType,
                      fillColor: context.cardColor,
                      filled: true,
                      suffixIcon: Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: darkGray.withValues(alpha: 0.5)),
                    ),
                  ),
                  16.height,

                  // Description
                  _label(locale.value.description),
                  6.height,
                  AppTextField(
                    textStyle: primaryTextStyle(size: 12),
                    controller: c.descriptionCont,
                    focus: c.descriptionFocus,
                    nextFocus: c.descriptionArFocus,
                    minLines: 3,
                    maxLength: 250,
                    textFieldType: TextFieldType.MULTILINE,
                    enableChatGPT: appConfigs.value.enableChatGpt.getBoolInt(),
                    promptFieldInputDecorationChatGPT: inputDecoration(
                      context,
                      hintText: locale.value.writeHere,
                      fillColor: context.scaffoldBackgroundColor,
                      filled: true,
                    ),
                    testWithoutKeyChatGPT: appConfigs.value.testWithoutKey.getBoolInt(),
                    loaderWidgetForChatGPT: const ChatGPTLoadingWidget(),
                    decoration: inputDecoration(
                      context,
                      hintText: locale.value.enterDescription,
                      fillColor: context.cardColor,
                      filled: true,
                    ),
                  ),
                  16.height,

                  // Description (Arabic)
                  _label(locale.value.descriptionInArabic),
                  6.height,
                  AppTextField(
                    textStyle: primaryTextStyle(size: 12),
                    controller: c.descriptionArCont,
                    focus: c.descriptionArFocus,
                    minLines: 3,
                    maxLength: 250,
                    textFieldType: TextFieldType.MULTILINE,
                    textAlign: TextAlign.right,
                    decoration: inputDecoration(
                      context,
                      hintText: locale.value.descriptionInArabicHint,
                      fillColor: context.cardColor,
                      filled: true,
                    ),
                  ),
                  16.height,

                  // Status
                  _buildStatusToggle(context),
                  24.height,

                  AppButton(
                    width: Get.width,
                    color: appColorPrimary,
                    onTap: () {
                      hideKeyboard(context);
                      c.saveService();
                    },
                    child: Text(
                      c.isEdit.value ? locale.value.update : locale.value.save,
                      style: primaryTextStyle(color: white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: boldTextStyle(size: 13),
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: boldTextStyle(size: 13, color: Colors.redAccent),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    return Obx(() {
      final hasLocal = c.imageFile.value.path.isNotEmpty;
      final hasRemote = c.serviceImage.value.isNotEmpty;
      if (hasLocal || hasRemote) {
        return Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              CachedImageWidget(
                url: hasLocal ? c.imageFile.value.path : c.serviceImage.value,
                height: 110,
                width: 110,
                fit: BoxFit.cover,
              ).cornerRadiusWithClipRRect(defaultRadius),
              Positioned(
                top: 110 * 3 / 4 + 4,
                left: 110 * 3 / 4 + 4,
                child: GestureDetector(
                  onTap: () {
                    hideKeyboard(context);
                    c.showBottomSheet(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: boxDecorationDefault(shape: BoxShape.circle, color: Colors.white),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: boxDecorationDefault(shape: BoxShape.circle, color: appColorPrimary),
                      child: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ).paddingBottom(16),
        );
      }
      return AppPrimaryWidget(
        width: Get.width,
        constraints: BoxConstraints(minHeight: Get.height * 0.18),
        backgroundColor: context.cardColor,
        border: Border.all(color: borderColor, width: 0.8),
        borderRadius: defaultRadius,
        onTap: () {
          hideKeyboard(context);
          c.showBottomSheet(context);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CachedImageWidget(
              url: Assets.iconsIcImageUpload,
              height: 32,
              fit: BoxFit.fitHeight,
            ),
            16.height,
            Text(
              locale.value.chooseImageToUpload,
              style: secondaryTextStyle(color: secondaryTextColor, size: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatusToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: boxDecorationDefault(
        color: context.cardColor,
        borderRadius: radius(defaultRadius / 2),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        children: [
          Text(locale.value.status, style: boldTextStyle(size: 13)).expand(),
          Obx(
            () => Switch(
              activeThumbColor: appColorPrimary,
              value: c.status.value,
              onChanged: (v) => c.status(v),
            ),
          ),
        ],
      ),
    );
  }

  void _openTypeSheet(BuildContext context) {
    serviceCommonBottomSheet(
      context,
      onSheetClose: (_) => hideKeyboard(context),
      child: BottomSelectionSheet(
        title: locale.value.selectType,
        hasError: false,
        isEmpty: false,
        hideSearchBar: true,
        isLoading: false.obs,
        listWidget: ListView.separated(
          shrinkWrap: true,
          itemCount: c.typeOptions.length,
          itemBuilder: (ctx, i) {
            final option = c.typeOptions[i];
            final label = option['key'] == ServiceTypes.inClinic ? locale.value.inClinic : locale.value.online;
            return SettingItemWidget(
              title: label,
              titleTextStyle: primaryTextStyle(size: 14),
              leading: Icon(
                option['key'] == ServiceTypes.inClinic ? Icons.local_hospital_outlined : Icons.videocam_outlined,
                color: appColorPrimary,
              ),
              onTap: () {
                c.selectType({'key': option['key']!, 'label': label});
                Get.back();
              },
            );
          },
          separatorBuilder: (_, __) => commonDivider.paddingSymmetric(vertical: 6),
        ),
      ),
    );
  }

  void _openClinicSheet(BuildContext context) {
    serviceCommonBottomSheet(
      context,
      onSheetClose: (_) => hideKeyboard(context),
      child: Obx(
        () => BottomSelectionSheet(
          title: locale.value.selectClinic,
          hintText: locale.value.searchClinicHere,
          hasError: c.hasErrorFetchingClinic.value,
          errorText: c.errorMessageClinic.value,
          isEmpty: c.clinicList.isEmpty,
          isLoading: c.isClinicLoading,
          searchTextCont: c.clinicSearchCont,
          onChanged: (text) {
            c.clinicSearchStream.add(text);
          },
          searchApiCall: (s) {
            c.clinicSearchCont.text = s;
            c.getClinics();
          },
          onRetry: () => c.getClinics(),
          listWidget: ListView.separated(
            shrinkWrap: true,
            itemCount: c.clinicList.length,
            itemBuilder: (ctx, i) {
              final ClinicData clinic = c.clinicList[i];
              return SettingItemWidget(
                title: clinic.name,
                subTitle: clinic.address,
                titleTextStyle: primaryTextStyle(size: 14),
                leading: CachedImageWidget(
                  url: clinic.clinicImage,
                  height: 35,
                  width: 35,
                  firstName: clinic.name,
                  fit: BoxFit.cover,
                  circle: true,
                ),
                onTap: () {
                  c.selectClinic(clinic);
                  Get.back();
                },
              );
            },
            separatorBuilder: (_, __) => commonDivider.paddingSymmetric(vertical: 6),
          ).expand(),
        ),
      ),
    );
  }
}
