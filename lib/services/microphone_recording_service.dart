import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'voice_logging.dart';

class MicrophoneRecordingService {
  MicrophoneRecordingService({AudioRecorder? recorder}) : _recorder = recorder;

  static const _sampleRate = 44100;
  static const _channelCount = 1;
  static const _bitsPerSample = 16;
  static const _silenceThreshold = 0.015;
  static const _silencePaddingMillis = 80;
  static const _stopTimeout = Duration(seconds: 5);

  AudioRecorder? _recorder;
  String? _activeRecordingPath;
  BytesBuilder? _pcmBuffer;
  StreamSubscription<Uint8List>? _pcmSubscription;
  Completer<void>? _pcmStreamDone;

  AudioRecorder get _audioRecorder => _recorder ??= AudioRecorder();

  Future<bool> requestMicrophoneAccess() async {
    final hasPermission = await _audioRecorder.hasPermission();
    _log('Microphone permission granted=$hasPermission');
    return hasPermission;
  }

  Future<void> startRecording() async {
    final tempDirectory = await getTemporaryDirectory();
    final path = p.join(
      tempDirectory.path,
      'tree-launcher-recording-${DateTime.now().microsecondsSinceEpoch}.wav',
    );

    final stream = await _audioRecorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: _channelCount,
      ),
    );
    _activeRecordingPath = path;
    _pcmBuffer = BytesBuilder(copy: false);
    final pcmStreamDone = Completer<void>();
    _pcmStreamDone = pcmStreamDone;
    _pcmSubscription = stream.listen(
      (chunk) {
        _pcmBuffer?.add(chunk);
      },
      onError: (Object error, StackTrace stackTrace) {
        _log('PCM stream failed.', error: error, stackTrace: stackTrace);
        if (!pcmStreamDone.isCompleted) {
          pcmStreamDone.completeError(error, stackTrace);
        }
      },
      onDone: () {
        _log('PCM stream closed.');
        if (!pcmStreamDone.isCompleted) {
          pcmStreamDone.complete();
        }
      },
      cancelOnError: true,
    );
    _log(
      'Recording started in PCM stream mode path=$path sampleRate=${_sampleRate}Hz',
    );
  }

  Future<String> stopRecordingAndTrim() async {
    final path = _activeRecordingPath;
    final pcmBuffer = _pcmBuffer;
    final pcmStreamDone = _pcmStreamDone;
    if (path == null || pcmBuffer == null || pcmStreamDone == null) {
      throw StateError('Recording was stopped without an active audio stream.');
    }
    _log('Stopping recording activePath=$path');
    await _audioRecorder.stop().timeout(_stopTimeout);
    await pcmStreamDone.future.timeout(_stopTimeout);
    final pcmBytes = pcmBuffer.takeBytes();
    _resetActiveStreamState();
    if (pcmBytes.isEmpty) {
      throw StateError('Recording finished without returning any audio data.');
    }
    _log('PCM capture finished path=$path size=${pcmBytes.length} bytes');
    await _writePcmAsWav(path: path, pcmBytes: pcmBytes);
    final trimmedPath = await _trimWavSilence(path);
    if (trimmedPath != path) {
      await _deleteIfExists(path);
    }
    _log('Trim stage completed outputPath=$trimmedPath');
    return trimmedPath;
  }

  Future<void> cancelRecording() async {
    _log('Cancelling active recording path=$_activeRecordingPath');
    await _audioRecorder.cancel();
    await _pcmSubscription?.cancel();
    final activeRecordingPath = _activeRecordingPath;
    _resetActiveStreamState();
    if (activeRecordingPath != null) {
      await _deleteIfExists(activeRecordingPath);
    }
  }

  Future<void> dispose() async {
    final recorder = _recorder;
    await _pcmSubscription?.cancel();
    _resetActiveStreamState();
    if (recorder == null) {
      return;
    }
    await recorder.dispose();
  }

  Future<String> _trimWavSilence(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    _log('Loaded WAV bytes path=$path size=${bytes.length}');
    if (bytes.length < 44) {
      throw const FormatException('Recorded WAV file is too short to trim.');
    }

    final data = ByteData.sublistView(bytes);
    if (_readAscii(bytes, 0, 4) != 'RIFF' ||
        _readAscii(bytes, 8, 4) != 'WAVE') {
      throw const FormatException('Recorded audio is not a WAV file.');
    }

    var offset = 12;
    int? dataOffset;
    int? dataLength;
    int? channelCount;
    int? sampleRate;
    int? bitsPerSample;
    int? dataChunkHeaderOffset;

    while (offset + 8 <= bytes.length) {
      final chunkId = _readAscii(bytes, offset, 4);
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      final chunkDataOffset = offset + 8;
      _log('Found WAV chunk id=$chunkId size=$chunkSize at=$offset');
      if (chunkDataOffset + chunkSize > bytes.length) {
        _log(
          'Chunk $chunkId overruns file bounds; stopping chunk scan at offset=$offset.',
        );
        break;
      }

      if (chunkId == 'fmt ') {
        final audioFormat = data.getUint16(chunkDataOffset, Endian.little);
        if (audioFormat != 1) {
          throw const FormatException(
            'Only PCM WAV recordings can be trimmed.',
          );
        }
        channelCount = data.getUint16(chunkDataOffset + 2, Endian.little);
        sampleRate = data.getUint32(chunkDataOffset + 4, Endian.little);
        bitsPerSample = data.getUint16(chunkDataOffset + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataChunkHeaderOffset = offset + 4;
        dataOffset = chunkDataOffset;
        dataLength = chunkSize;
      }

      offset = chunkDataOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (dataOffset == null || dataLength == null) {
      throw const FormatException('Recorded WAV file is missing a data chunk.');
    }
    if (channelCount == null || sampleRate == null || bitsPerSample == null) {
      throw const FormatException(
        'Recorded WAV file is missing format metadata.',
      );
    }
    if (bitsPerSample != 16) {
      throw const FormatException('Only 16-bit WAV recordings can be trimmed.');
    }
    _log(
      'Parsed WAV metadata channels=$channelCount sampleRate=$sampleRate '
      'bitsPerSample=$bitsPerSample dataOffset=$dataOffset dataLength=$dataLength',
    );

    final bytesPerSample = bitsPerSample ~/ 8;
    final frameSize = channelCount * bytesPerSample;
    if (frameSize <= 0 || dataLength < frameSize) {
      throw const FormatException(
        'Recorded WAV file contains invalid audio data.',
      );
    }
    final originalDataLength = dataLength;
    final alignedDataLength =
        originalDataLength - (originalDataLength % frameSize);
    if (alignedDataLength != originalDataLength) {
      _log(
        'Aligning data chunk length from $originalDataLength to $alignedDataLength for frame scanning.',
      );
      dataLength = alignedDataLength;
    }

    final sampleBytes = bytes.sublist(dataOffset, dataOffset + dataLength);
    final sampleData = ByteData.sublistView(Uint8List.fromList(sampleBytes));
    final totalFrames = dataLength ~/ frameSize;
    final paddingFrames = ((sampleRate * _silencePaddingMillis) / 1000).round();
    _log(
      'Scanning audio for silence totalFrames=$totalFrames frameSize=$frameSize '
      'paddingFrames=$paddingFrames threshold=$_silenceThreshold',
    );

    int? startFrame;
    int? endFrame;

    for (var frame = 0; frame < totalFrames; frame++) {
      if (_frameAmplitude(sampleData, frame, channelCount, frameSize) >
          _silenceThreshold) {
        startFrame = frame > paddingFrames ? frame - paddingFrames : 0;
        break;
      }
    }

    for (var frame = totalFrames - 1; frame >= 0; frame--) {
      if (_frameAmplitude(sampleData, frame, channelCount, frameSize) >
          _silenceThreshold) {
        endFrame = frame + paddingFrames < totalFrames
            ? frame + paddingFrames
            : totalFrames - 1;
        break;
      }
    }

    if (startFrame == null || endFrame == null || endFrame < startFrame) {
      _log('No non-silent region detected; keeping original recording.');
      return path;
    }
    _log('Detected non-silent frames start=$startFrame end=$endFrame');

    final trimmedDataStart = dataOffset + (startFrame * frameSize);
    final trimmedDataEnd = dataOffset + ((endFrame + 1) * frameSize);
    final trimmedDataLength = trimmedDataEnd - trimmedDataStart;
    if (trimmedDataLength == dataLength) {
      _log(
        'Trimming not needed after silence scan; keeping original recording.',
      );
      return path;
    }
    final dataChunkEnd = dataOffset + originalDataLength;

    final trimmedBytes = Uint8List.fromList([
      ...bytes.sublist(0, dataOffset),
      ...bytes.sublist(trimmedDataStart, trimmedDataEnd),
      ...bytes.sublist(dataChunkEnd),
    ]);

    final trimmedByteData = ByteData.sublistView(trimmedBytes);
    trimmedByteData.setUint32(4, trimmedBytes.length - 8, Endian.little);
    trimmedByteData.setUint32(
      dataChunkHeaderOffset!,
      trimmedDataLength,
      Endian.little,
    );

    final trimmedPath = p.join(
      file.parent.path,
      'tree-launcher-trimmed-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    await File(trimmedPath).writeAsBytes(trimmedBytes, flush: true);
    _log(
      'Wrote trimmed recording path=$trimmedPath '
      'trimmedSize=${trimmedBytes.length} trimmedDataLength=$trimmedDataLength',
    );
    return trimmedPath;
  }

  double _frameAmplitude(
    ByteData sampleData,
    int frameIndex,
    int channelCount,
    int frameSize,
  ) {
    final frameOffset = frameIndex * frameSize;
    var amplitude = 0.0;

    for (var channel = 0; channel < channelCount; channel++) {
      final sample = sampleData.getInt16(
        frameOffset + (channel * 2),
        Endian.little,
      );
      final normalized = sample.abs() / 32768.0;
      if (normalized > amplitude) {
        amplitude = normalized;
      }
    }

    return amplitude;
  }

  String _readAscii(Uint8List bytes, int offset, int length) {
    return String.fromCharCodes(bytes.sublist(offset, offset + length));
  }

  Future<void> _writePcmAsWav({
    required String path,
    required Uint8List pcmBytes,
  }) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final blockAlign = _channelCount * (_bitsPerSample ~/ 8);
    final byteRate = _sampleRate * blockAlign;
    final header = ByteData(44);
    _writeAscii(header, 0, 'RIFF');
    header.setUint32(4, 36 + pcmBytes.length, Endian.little);
    _writeAscii(header, 8, 'WAVE');
    _writeAscii(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, _channelCount, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, _bitsPerSample, Endian.little);
    _writeAscii(header, 36, 'data');
    header.setUint32(40, pcmBytes.length, Endian.little);

    final wavBytes = Uint8List(44 + pcmBytes.length)
      ..setRange(0, 44, header.buffer.asUint8List())
      ..setRange(44, 44 + pcmBytes.length, pcmBytes);
    await file.writeAsBytes(wavBytes, flush: true);
    _log('Wrote WAV file path=$path size=${wavBytes.length} bytes');
  }

  void _writeAscii(ByteData data, int offset, String value) {
    final bytes = ascii.encode(value);
    for (var index = 0; index < bytes.length; index++) {
      data.setUint8(offset + index, bytes[index]);
    }
  }

  void _resetActiveStreamState() {
    _activeRecordingPath = null;
    _pcmBuffer = null;
    _pcmSubscription = null;
    _pcmStreamDone = null;
  }

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    logVoice('Recorder', message, error: error, stackTrace: stackTrace);
  }
}
