import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/entities/driver_profile.dart';
import '../../domain/repositories/driver_repository.dart';

class DriverRegistrationState {
  const DriverRegistrationState({
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.truckPlateNumber = '',
    this.truckCapacity = 10000,
    this.licenseNumber = '',
    this.assignedArea = '',
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
    this.validationError,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String truckPlateNumber;
  final double truckCapacity;
  final String licenseNumber;
  final String assignedArea;
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;
  final String? validationError;

  DriverRegistrationState copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? truckPlateNumber,
    double? truckCapacity,
    String? licenseNumber,
    String? assignedArea,
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
    String? validationError,
    bool clearError = false,
    bool clearValidation = false,
  }) {
    return DriverRegistrationState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      truckPlateNumber: truckPlateNumber ?? this.truckPlateNumber,
      truckCapacity: truckCapacity ?? this.truckCapacity,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      assignedArea: assignedArea ?? this.assignedArea,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      validationError:
          clearValidation ? null : validationError ?? this.validationError,
    );
  }
}

class DriverRegistrationNotifier extends Notifier<DriverRegistrationState> {
  @override
  DriverRegistrationState build() =>
      DriverRegistrationState(assignedArea: AppStrings.gazaAreas.first);

  void setFirstName(String v) =>
      state = state.copyWith(firstName: v, clearValidation: true);
  void setLastName(String v) =>
      state = state.copyWith(lastName: v, clearValidation: true);
  void setPhone(String v) =>
      state = state.copyWith(phone: v, clearValidation: true);
  void setTruckPlateNumber(String v) =>
      state = state.copyWith(truckPlateNumber: v, clearValidation: true);
  void setTruckCapacity(double v) =>
      state = state.copyWith(truckCapacity: v, clearValidation: true);
  void setLicenseNumber(String v) =>
      state = state.copyWith(licenseNumber: v, clearValidation: true);
  void setAssignedArea(String v) =>
      state = state.copyWith(assignedArea: v, clearValidation: true);

  bool _validate() {
    if (state.firstName.trim().isEmpty) {
      state = state.copyWith(validationError: 'يرجى إدخال الاسم الأول');
      return false;
    }
    if (state.lastName.trim().isEmpty) {
      state = state.copyWith(validationError: 'يرجى إدخال اسم العائلة');
      return false;
    }
    if (state.phone.trim().isEmpty) {
      state = state.copyWith(validationError: 'يرجى إدخال رقم الهاتف');
      return false;
    }
    if (state.truckPlateNumber.trim().isEmpty) {
      state = state.copyWith(validationError: 'يرجى إدخال رقم لوحة الشاحنة');
      return false;
    }
    if (state.licenseNumber.trim().isEmpty) {
      state = state.copyWith(validationError: 'يرجى إدخال رقم رخصة القيادة');
      return false;
    }
    if (state.assignedArea.trim().isEmpty) {
      state =
          state.copyWith(validationError: 'يرجى اختيار المنطقة المكلّف بها');
      return false;
    }
    state = state.copyWith(clearValidation: true);
    return true;
  }

  Future<void> submit() async {
    if (!_validate()) return;
    if (state.isSubmitting) return;

    final uid = GetIt.I<AuthRepository>().currentUser?.uid;
    if (uid == null) {
      state = state.copyWith(errorMessage: 'يجب تسجيل الدخول أولاً');
      return;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    final profile = DriverProfile(
      uid: uid,
      firstName: state.firstName.trim(),
      lastName: state.lastName.trim(),
      phone: state.phone.trim(),
      truckPlateNumber: state.truckPlateNumber.trim(),
      truckCapacity: state.truckCapacity,
      licenseNumber: state.licenseNumber.trim(),
      assignedArea: state.assignedArea.trim(),
      registeredAt: DateTime.now(),
    );

    final result =
        await GetIt.I<DriverRepository>().registerDriverProfile(profile);

    await result.fold(
      (failure) async => state = state.copyWith(
        isSubmitting: false,
        errorMessage: failure.message,
      ),
      (_) async {
        // Creating the drivers/{uid} doc triggers the Cloud Function that
        // sets the `role: driver` custom claim — wait for it so the
        // router's very next redirect already sees the correct role
        // instead of racing it.
        await GetIt.I<AuthRepository>().waitForRoleClaim();
        state = state.copyWith(isSubmitting: false, isSuccess: true);
      },
    );
  }
}

final driverRegistrationProvider =
    NotifierProvider<DriverRegistrationNotifier, DriverRegistrationState>(
  DriverRegistrationNotifier.new,
);
