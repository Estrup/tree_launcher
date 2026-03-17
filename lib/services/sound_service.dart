import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';

class SoundService {
  static const MethodChannel _channel = MethodChannel(
    'tree_launcher/system_sound',
  );

  List<CopilotAttentionSound> get supportedCopilotAttentionSounds =>
      CopilotAttentionSound.values;

  Future<void> playSystemSound(CopilotAttentionSound sound) async {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    await _channel.invokeMethod<void>('playSystemSound', {
      'soundName': sound.systemName,
    });
  }
}
