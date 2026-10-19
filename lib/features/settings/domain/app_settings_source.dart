import 'package:tree_launcher/features/settings/domain/app_settings.dart';

/// The app's current settings, for readers outside the UI such as the agent
/// HTTP API.
///
/// Implemented by the live `SettingsController`, whose in-memory settings are
/// the ones the app saves.
abstract interface class AppSettingsSource {
  AppSettings get settings;
}
