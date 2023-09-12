import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

/// The [GuardManager] checks a list of [Guard]s before it performs the function
/// defined by [onSuccess]
/// If any [Guard] fails, it shows a [Dialog] provided by the guard.
/// The expectation is that the dialog opens a settings page and puts this application
/// in the background. When this application is resumed, the checks are run again.
class GuardManager extends StatefulWidget {
  const GuardManager({
    super.key,
    required this.guards,
    required this.onSuccess,
    required this.onFailure,
    required this.child,
  });

  /// The list of [Guard]s to check
  final List<Guard> guards;

  /// The function to perform if each [Guard] has passed
  final void Function() onSuccess;

  /// The function to perform if any [Guard] has failed
  final void Function() onFailure;

  /// The child of this [Widget] (Typically the widgets being guarded)
  final Widget child;

  @override
  State<GuardManager> createState() => _GuardManagerState();
}

class _GuardManagerState extends State<GuardManager>
    with WidgetsBindingObserver {
  /// Whether there is a guard active at this time
  bool _activeGuard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) async => _checkGuards(context));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && !_activeGuard) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) async => _checkGuards(context));
    }
  }

  void _checkGuards(BuildContext context) async {
    bool success = true;
    for (final guard in widget.guards) {
      _activeGuard = true;
      success &= await guard.check();
      if (!success) {
        // Display the dialog provided by the guard
        if (context.mounted) {
          await showDialog(context: context, builder: guard.dialogBuilder);
        }
        break;
      }
    }
    _activeGuard = false;
    if (success) {
      widget.onSuccess();
    } else {
      widget.onFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// A class that performs a check and displays a dialog if the check fails
abstract class Guard {
  /// The check to perform for the guard
  Future<bool> check();

  /// A function that is provided to the [showDialog] builder
  Widget dialogBuilder(BuildContext buildContext);
}

/// A generic [Guard] where the check and dialog is provided on construction
class ServiceGuard implements Guard {
  const ServiceGuard({
    required Future<bool> Function() check,
    required this.alertDialog,
  }) : _check = check;

  final Future<bool> Function() _check;
  final SystemSettingsAlertDialog alertDialog;

  @override
  Future<bool> check() => _check();

  @override
  Widget dialogBuilder(BuildContext buildContext) =>
      alertDialog.dialogBuilder(buildContext);
}

/// A [Guard] that checks if [Permission]s were granted by the user
/// If the check fails, it displays a dialog that opens the applications
/// settings page
class PermissionGuard implements Guard {
  const PermissionGuard(
      {required this.permissions,
      required this.title,
      required this.rationale});

  /// The list of [Permission]s to check
  final List<Permission> permissions;

  /// The title of the alert dialog
  final String title;

  /// The rational for the alert
  final String rationale;

  @override
  Future<bool> check() async {
    final permissionStatus = await permissions.request();
    bool allGranted = true;
    permissionStatus.forEach((permission, status) {
      if (status != PermissionStatus.granted) {
        allGranted &= false;
      }
    });
    return allGranted;
  }

  @override
  Widget dialogBuilder(BuildContext buildContext) {
    return SystemSettingsAlertDialog(
      title: title,
      rationale: rationale,
      appSettingsType: AppSettingsType.settings,
    ).dialogBuilder(buildContext);
  }
}

/// The [SystemSettingsAlertDialog] can be displayed if a system setting on
/// the mobile device needs to be modified for the application to work
/// It provides a dialog builder that can be passed to [showDialog]
/// It provides the user with a 'Dismiss' button and an 'Open settings' button
/// The particular setting to open can be assigned to the [appSettingsType] parameter
class SystemSettingsAlertDialog {
  const SystemSettingsAlertDialog({
    required this.title,
    required this.rationale,
    required this.appSettingsType,
    this.navigateBackOnDismiss = true,
  });

  /// The title for the alert dialog
  final String title;

  /// The rationale for the alert
  final String rationale;

  /// The app settings to open when "Open settings" is clicked
  final AppSettingsType appSettingsType;

  /// Whether to navigate back on dismiss
  final bool navigateBackOnDismiss;

  Widget dialogBuilder(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Text(rationale),
      actions: [
        TextButton(
          child: const Text('Dismiss'),
          onPressed: () {
            context.pop(); // Dismiss dialog
            if (navigateBackOnDismiss) {
              context.pop(); // Navigate back to previous screen
            }
          },
        ),
        TextButton(
          child: const Text('Open settings'),
          onPressed: () {
            AppSettings.openAppSettings(type: appSettingsType);
            context.pop();
          },
        ),
      ],
    );
  }
}
