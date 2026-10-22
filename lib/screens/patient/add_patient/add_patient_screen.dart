import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../../components/app_scaffold.dart';
import '../../../generated/assets.dart';
import '../../../main.dart';
import '../../../utils/colors.dart';
import '../../../utils/common_base.dart';
import '../../../utils/constants.dart';
import 'add_patient_controller.dart';

class AddPatientScreen extends StatelessWidget {
  AddPatientScreen({super.key});

  final AddPatientController addPatientCont = Get.put(AddPatientController());

  @override
  Widget build(BuildContext context) {
    return AppScaffoldNew(
      appBartitleText: addPatientCont.isEdit ? locale.value.editPatient : locale.value.addPatient,
      isLoading: addPatientCont.isLoading,
      appBarVerticalSize: Get.height * 0.12,
      body: Form(
        key: addPatientCont.formKey,
        autovalidateMode: AutovalidateMode.onUnfocus,
        child: AnimatedScrollView(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100, top: 16),
          children: [
            AppTextField(
              textStyle: primaryTextStyle(size: 12),
              controller: addPatientCont.firstNameCont,
              focus: addPatientCont.firstNameFocus,
              nextFocus: addPatientCont.lastNameFocus,
              textFieldType: TextFieldType.NAME,
              errorThisFieldRequired: locale.value.thisFieldIsRequired,
              decoration: inputDecoration(context, hintText: locale.value.firstName, fillColor: context.cardColor, filled: true),
              suffix: commonLeadingWid(imgPath: Assets.navigationIcUserOutlined, color: secondaryTextColor, size: 12).paddingAll(16),
            ),
            16.height,
            AppTextField(
              textStyle: primaryTextStyle(size: 12),
              controller: addPatientCont.lastNameCont,
              focus: addPatientCont.lastNameFocus,
              nextFocus: addPatientCont.phoneFocus,
              textFieldType: TextFieldType.NAME,
              errorThisFieldRequired: locale.value.thisFieldIsRequired,
              decoration: inputDecoration(context, hintText: locale.value.lastName, fillColor: context.cardColor, filled: true),
              suffix: commonLeadingWid(imgPath: Assets.navigationIcUserOutlined, color: secondaryTextColor, size: 12).paddingAll(16),
            ),
            16.height,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () => AppTextField(
                    textStyle: primaryTextStyle(size: 12),
                    textFieldType: TextFieldType.OTHER,
                    controller: TextEditingController(text: "  +${addPatientCont.pickedPhoneCode.value.phoneCode}"),
                    readOnly: true,
                    isValidationRequired: false,
                    onTap: () {
                      pickCountry(
                        context,
                        onSelect: (Country country) => addPatientCont.pickedPhoneCode(country),
                      );
                    },
                    textAlign: TextAlign.center,
                    decoration: inputDecoration(
                      context,
                      hintText: "",
                      prefixIcon: Text(addPatientCont.pickedPhoneCode.value.flagEmoji).paddingOnly(top: 2, left: 8),
                      prefixIconConstraints: BoxConstraints.tight(const Size(24, 24)),
                      suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: dividerColor, size: 22).paddingOnly(right: 32),
                      suffixIconConstraints: BoxConstraints.tight(const Size(32, 24)),
                      fillColor: context.cardColor,
                      filled: true,
                    ),
                  ),
                ).expand(flex: 3),
                16.width,
                AppTextField(
                  textStyle: primaryTextStyle(size: 12),
                  textFieldType: TextFieldType.PHONE,
                  controller: addPatientCont.phoneCont,
                  focus: addPatientCont.phoneFocus,
                  nextFocus: addPatientCont.emailFocus,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                  validator: (value) {
                    final String digits = value.validate().trim();
                    if (digits.isEmpty) return locale.value.thisFieldIsRequired;
                    if (digits.length < 6 || digits.length > 15) return locale.value.pleaseEnterValidMobileNumber;
                    return null;
                  },
                  decoration: inputDecoration(context, hintText: locale.value.mobileNumber, fillColor: context.cardColor, filled: true),
                  suffix: commonLeadingWid(imgPath: Assets.iconsIcCall, color: secondaryTextColor, size: 12).paddingAll(16),
                ).expand(flex: 8),
              ],
            ),
            16.height,
            AppTextField(
              textStyle: primaryTextStyle(size: 12),
              controller: addPatientCont.emailCont,
              focus: addPatientCont.emailFocus,
              nextFocus: addPatientCont.addressFocus,
              textFieldType: TextFieldType.EMAIL_ENHANCED,
              // Optional: walk-in patients often have no email.
              validator: (value) {
                final String email = value.validate().trim();
                if (email.isEmpty) return null;
                return email.validateEmailEnhanced() ? null : locale.value.pleaseEnterValidEmail;
              },
              decoration: inputDecoration(context, hintText: "${locale.value.email} (${locale.value.optional})", fillColor: context.cardColor, filled: true),
              suffix: commonLeadingWid(imgPath: Assets.iconsIcMail, color: secondaryTextColor, size: 12).paddingAll(16),
            ),
            16.height,
            Text(locale.value.gender, style: primaryTextStyle()),
            8.height,
            Obx(
              () => Wrap(
                spacing: 16,
                runSpacing: 12,
                children: genders.map((gender) {
                  final bool isSelected = addPatientCont.selectedGender.value.id == gender.id;
                  return InkWell(
                    onTap: () => addPatientCont.selectedGender(gender),
                    borderRadius: radius(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: boxDecorationDefault(color: isSelected ? appColorPrimary : context.cardColor),
                      child: Text(gender.name, style: secondaryTextStyle(color: isSelected ? white : null)),
                    ),
                  );
                }).toList(),
              ),
            ),
            16.height,
            AppTextField(
              textStyle: primaryTextStyle(size: 12),
              controller: addPatientCont.dateOfBirthCont,
              textFieldType: TextFieldType.OTHER,
              readOnly: true,
              isValidationRequired: false,
              onTap: () => addPatientCont.pickDateOfBirth(context),
              decoration: inputDecoration(
                context,
                hintText: "${locale.value.dateOfBirth} (${locale.value.optional})",
                fillColor: context.cardColor,
                filled: true,
                suffixIcon: commonLeadingWid(imgPath: Assets.iconsIcCalendar, color: iconColor, size: 10).paddingAll(16),
              ),
            ),
            16.height,
            AppTextField(
              textStyle: primaryTextStyle(size: 12),
              controller: addPatientCont.addressCont,
              focus: addPatientCont.addressFocus,
              textFieldType: TextFieldType.MULTILINE,
              minLines: 1,
              isValidationRequired: false,
              decoration: inputDecoration(context, hintText: "${locale.value.address} (${locale.value.optional})", fillColor: context.cardColor, filled: true),
              suffix: commonLeadingWid(imgPath: Assets.iconsIcLocation, size: 12).paddingAll(16),
            ),
          ],
        ),
      ),
      widgetsStackedOverBody: [
        Positioned(
          bottom: 16,
          height: 50,
          width: Get.width,
          child: AppButton(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: Get.width,
            text: addPatientCont.isEdit ? locale.value.update : locale.value.save,
            color: appColorSecondary,
            textStyle: appButtonTextStyleWhite,
            shapeBorder: RoundedRectangleBorder(borderRadius: radius(defaultAppButtonRadius / 2)),
            onTap: addPatientCont.save,
          ),
        ),
      ],
    );
  }
}
