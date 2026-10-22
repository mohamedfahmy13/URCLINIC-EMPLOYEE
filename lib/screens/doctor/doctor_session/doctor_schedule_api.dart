import '../../../network/network_utils.dart';
import 'package:nb_utils/nb_utils.dart';
import 'doctor_schedule_model.dart';

class DoctorScheduleApi {
  Future<DoctorSchedule> load(int doctorId, {int? clinicId}) async {
    final query = Uri(queryParameters: {
      'doctor_id': '$doctorId',
      if (clinicId != null && clinicId > 0) 'clinic_id': '$clinicId',
    }).query;
    final response =
        await handleResponse(await buildHttpResponse('doctor-session?$query'));
    return DoctorSchedule.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> save(int doctorId, DoctorSchedule schedule) async {
    await handleResponse(await buildHttpResponse(
        'save-doctor-session/$doctorId',
        method: HttpMethodType.POST,
        request: {
          'doctor_id': doctorId,
          'clinic_id': schedule.clinicId,
          'weekdays': schedule.days.map((d) => d.toJson()).toList(),
        }));
  }
}
