import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../../shared/models/household_model.dart';
import '../../../../shared/services/priority_service.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/repositories/household_repository.dart';

class RegistrationFormState {
  const RegistrationFormState({
    this.selectedArea = 'الشجاعية',
    this.householdSize = 4,
    this.hasElderly = false,
    this.hasSick = false,
    this.hasChildren = false,
    this.isSubmitting = false,
    this.isSuccess = false,
    this.isEditingExisting = false,
    this.errorMessage,
    this.validationError,
    this.familyName = '',
  });

  final String selectedArea;
  final int householdSize;
  final bool hasElderly;
  final bool hasSick;
  final bool hasChildren;
  final bool isSubmitting;
  final bool isSuccess;
  final String familyName;

  /// True once an existing household record was found for the signed-in
  /// user and loaded into the form — lets the UI say "update" instead of
  /// "register" if it wants to.
  final bool isEditingExisting;
  final String? errorMessage;
  final String? validationError;

  RegistrationFormState copyWith({
    String? selectedArea,
    int? householdSize,
    bool? hasElderly,
    bool? hasSick,
    bool? hasChildren,
    bool? isSubmitting,
    bool? isSuccess,
    bool? isEditingExisting,
    String? errorMessage,
    String? validationError,
    String? familyName,
    bool clearError = false,
    bool clearValidation = false,
  }) {
    return RegistrationFormState(
      selectedArea: selectedArea ?? this.selectedArea,
      householdSize: householdSize ?? this.householdSize,
      hasElderly: hasElderly ?? this.hasElderly,
      hasSick: hasSick ?? this.hasSick,
      hasChildren: hasChildren ?? this.hasChildren,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      isEditingExisting: isEditingExisting ?? this.isEditingExisting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      validationError:
          clearValidation ? null : validationError ?? this.validationError,
      familyName: familyName ?? this.familyName,
    );
  }
}

class RegistrationNotifier extends Notifier<RegistrationFormState> {
  @override
  RegistrationFormState build() => const RegistrationFormState();

  void setFamilyName(String value) {
    // Deliberately NOT trimmed here: RegistrationScreen's edit flow syncs
    // its TextEditingController back from `state.familyName` whenever they
    // differ (to support pre-filling existing data), so trimming on every
    // keystroke made the controller fight the user — typing a space
    // between words in a multi-word family name got silently deleted the
    // instant it was typed, since the trimmed state no longer matched the
    // controller's raw (still-has-the-trailing-space) text. Trimming
    // happens once, at the actual validation/save boundary instead.
    state = state.copyWith(
      familyName: value,
      clearValidation: true,
    );
  }

  void setArea(String area) {
    state = state.copyWith(
      selectedArea: area.trim(),
      clearValidation: true,
    );
  }

  void setHouseholdSize(int size) {
    final clamped = size.clamp(1, 20);
    state = state.copyWith(householdSize: clamped, clearValidation: true);
  }

  void setHasElderly({required bool value}) {
    state = state.copyWith(hasElderly: value);
  }

  void setHasSick({required bool value}) {
    state = state.copyWith(hasSick: value);
  }

  void setHasChildren({required bool value}) {
    state = state.copyWith(hasChildren: value);
  }

  /// Loads the signed-in user's existing household (if any) so opening
  /// this screen a second time — e.g. from Settings → "تعديل بيانات
  /// الأسرة" — edits the same record instead of starting from scratch.
  /// A no-op for a brand-new resident who has nothing registered yet.
  Future<void> loadExistingIfAny() async {
    final uid = GetIt.I<AuthRepository>().currentUser?.uid;
    if (uid == null) return;

    final result = await GetIt.I<HouseholdRepository>().getHousehold(uid);

    result.fold(
      (failure) => AppLogger.warning(
        'Could not load existing household for uid=$uid: '
        '${failure.message}',
        tag: 'Registration',
      ),
      (household) {
        if (household == null) return;
        state = state.copyWith(
          familyName: household.familyName,
          selectedArea: household.areaName,
          householdSize: household.householdSize,
          hasElderly: household.hasElderly,
          hasSick: household.hasSick,
          hasChildren: household.hasChildren,
          isEditingExisting: true,
        );
      },
    );
  }

  /// Used by the onboarding wizard to block advancing off the family-name
  /// step until it's filled in. Shares the exact message (and the same
  /// inline banner display) [_validate] uses at final submission, instead
  /// of a separate ad hoc SnackBar with its own hardcoded copy.
  bool validateFamilyName() {
    if (state.familyName.trim().isEmpty) {
      state = state.copyWith(validationError: 'يرجى إدخال اسم العائلة');
      return false;
    }
    state = state.copyWith(clearValidation: true);
    return true;
  }

  bool _validate() {
    if (state.familyName.trim().isEmpty) {
      state = state.copyWith(
        validationError: 'يرجى إدخال اسم العائلة',
      );
      return false;
    }
    if (state.selectedArea.isEmpty) {
      state = state.copyWith(validationError: FailureMessages.areaRequired);
      return false;
    }
    if (state.householdSize < 1) {
      state = state.copyWith(
        validationError: FailureMessages.householdSizeTooSmall,
      );
      return false;
    }
    if (state.householdSize > 20) {
      state = state.copyWith(
        validationError: FailureMessages.householdSizeTooLarge,
      );
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

    // Trimmed once, here at the save boundary — kept untrimmed in state
    // itself so the edit-flow controller sync in RegistrationScreen
    // doesn't fight the user while they're still typing (see
    // setFamilyName).
    final familyName = state.familyName.trim();

    final vulnerabilityScore = HouseholdModel(
      id: uid,
      familyName: familyName,
      areaName: state.selectedArea,
      householdSize: state.householdSize,
      hasElderly: state.hasElderly,
      hasSick: state.hasSick,
      hasChildren: state.hasChildren,
      registeredAt: DateTime.now(),
    ).vulnerabilityScore;

    final priorityScore = GetIt.I<PriorityService>().calculatePriority(
      householdCount: state.householdSize,
      vulnerabilityScore: vulnerabilityScore,
      daysSinceServed: 0,
    );

    final household = HouseholdModel(
      id: uid,
      familyName: familyName,
      areaName: state.selectedArea,
      householdSize: state.householdSize,
      hasElderly: state.hasElderly,
      hasSick: state.hasSick,
      hasChildren: state.hasChildren,
      daysSinceLastDelivery: 0,
      priorityScore: priorityScore,
      registeredAt: DateTime.now(),
    );

    // households/{uid} — a stable, one-per-user document. Re-submitting
    // (editing) merges into the same record instead of creating a
    // duplicate; see HouseholdFirebaseSource.saveHousehold.
    final result = await GetIt.I<HouseholdRepository>().saveHousehold(
      uid: uid,
      household: household,
    );

    await result.fold(
      (failure) async {
        AppLogger.error(
          'Registration submission failed: ${failure.message}',
          tag: 'Registration',
        );
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: FailureMessages.fromFailure(failure),
        );
      },
      (_) async {
        await GetIt.I<SecureStorageService>()
            .setRegistrationComplete(householdId: uid);
        await GetIt.I<SecureStorageService>().saveArea(state.selectedArea);

        // households/{uid} creation triggers the Cloud Function that sets
        // the `role: resident` custom claim — wait for it so the router's
        // next redirect already has it (mirrors the driver flow).
        await GetIt.I<AuthRepository>().waitForRoleClaim();

        AppLogger.info(
          'Household saved for uid=$uid in ${state.selectedArea} '
          '(size=${state.householdSize}, priority=$priorityScore)',
          tag: 'Registration',
        );

        state = state.copyWith(
          isSubmitting: false,
          isSuccess: true,
          isEditingExisting: true,
        );
      },
    );
  }
}

final registrationProvider =
    NotifierProvider<RegistrationNotifier, RegistrationFormState>(
  RegistrationNotifier.new,
);
