import 'dart:io';

import 'package:http/http.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../../models/base_response_model.dart';
import '../../../network/network_utils.dart';
import '../../../utils/api_end_points.dart';
import '../../../utils/app_common.dart';
import '../../category/model/all_category_model.dart';

class ServiceFormApis {
  static Future<BaseResponseModel> removeService({required int serviceId}) async {
    return BaseResponseModel.fromJson(await handleResponse(await buildHttpResponse('${APIEndPoints.deleteService}/$serviceId', method: HttpMethodType.POST)));
  }

  static Future<CategoryListRes> getCategory() async {
    return CategoryListRes.fromJson(await handleResponse(await buildHttpResponse(APIEndPoints.getCategoryList)));
  }

  static Future<BaseResponseModel> updateServicesStatus({required int serviceId, required Map request}) async {
    return BaseResponseModel.fromJson(await handleResponse(await buildHttpResponse("${APIEndPoints.updateClinicService}/$serviceId", request: request, method: HttpMethodType.POST)));
  }

  /// Create or update a service via multipart upload (image + fields).
  static Future<dynamic> saveService({
    required Map<String, dynamic> request,
    File? imageFile,
    int? serviceId,
    bool isEdit = false,
    Function(dynamic)? onSuccess,
    Function(dynamic)? onError,
  }) async {
    if (!isLoggedIn.value) return null;

    final String endpoint = isEdit && serviceId != null
        ? '${APIEndPoints.updateClinicService}/$serviceId'
        : APIEndPoints.addService;

    final MultipartRequest multiPartRequest = await getMultiPartRequest(endpoint);
    multiPartRequest.fields.addAll(await getMultipartFields(val: request));

    // The backend reads the service image from `file_url` (store/update in ClinicsServiceController).
    if (imageFile != null && imageFile.path.isNotEmpty) {
      multiPartRequest.files.add(await MultipartFile.fromPath('file_url', imageFile.path));
    }

    multiPartRequest.headers.addAll(buildHeaderTokens());

    await sendMultiPartRequest(
      multiPartRequest,
      toastValidationError: false,
      onSuccess: (data) async {
        onSuccess?.call(data);
      },
      onError: (error) {
        onError?.call(error);
        throw error;
      },
    ).catchError((error) {
      throw error;
    });
  }
}
