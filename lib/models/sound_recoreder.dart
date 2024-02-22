import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'dart:async';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class SoundRecorder {
  FlutterSoundRecorder? _audioRecorder;
  bool _isRecorderInitialized = false;

  bool get isRecording => _audioRecorder?.isRecording ?? false;

  Future init() async {
    _audioRecorder = FlutterSoundRecorder();

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('마이크 권한이 거부되었습니다.');
    }

    await _audioRecorder!.openRecorder();
    _isRecorderInitialized = true;
  }

  Future startRecording() async {
    if (!_isRecorderInitialized) return;
    final dir = await path_provider.getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/my_recording_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _audioRecorder!.startRecorder(toFile: filePath);
  }

  Future stopRecording() async {
    if (!_isRecorderInitialized) return;

    final path = await _audioRecorder!.stopRecorder();
    final File file = File(path!);
    print('녹음 파일 저장 위치: $path');

    // 필요한 경우 파일 처리
  }

  void dispose() {
    if (_audioRecorder != null) {
      _audioRecorder!.closeRecorder();
      _audioRecorder = null;
    }
    _isRecorderInitialized = false;
  }
}
