import 'dart:convert';

import 'qualification_model.dart';

class AddDoctorReq {
  String firstName;
  String lastName;
  String email;
  String gender;
  String mobile;
  List<int> clinicId;
  String status;
  List<int> serviceId;
  String aboutSelf;
  String expert;
  String facebookLink;
  String instagramLink;
  String twitterLink;
  String dribbbleLink;
  String address;
  String city;
  String state;
  String country;
  String pincode;
  String latitude;
  String longitude;
  String experience;
  List<QualificationModel> qualifications;

  AddDoctorReq({
    this.firstName = "",
    this.lastName = "",
    this.email = "",
    this.gender = "",
    this.mobile = "",
    this.clinicId = const [],
    this.status = "",
    this.serviceId = const [],
    this.aboutSelf = "",
    this.expert = "",
    this.facebookLink = "",
    this.instagramLink = "",
    this.twitterLink = "",
    this.dribbbleLink = "",
    this.address = "",
    this.city = "",
    this.state = "",
    this.country = "",
    this.pincode = "",
    this.latitude = "",
    this.longitude = "",
    this.experience = "",
    this.qualifications = const <QualificationModel>[],
  });

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'doctor_email': email,
      'gender': gender,
      'mobile': mobile,
      'clinic_id': clinicId,
      'status': status,
      'service_id': serviceId,
      'about_self': aboutSelf,
      'expert': expert,
      'facebook_link': facebookLink,
      'instagram_link': instagramLink,
      'twitter_link': twitterLink,
      'dribbble_link': dribbbleLink,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'experience': experience,
      'qualifications':
          jsonEncode(qualifications.map((e) => e.toJson()).toList()),
    };
  }
}
