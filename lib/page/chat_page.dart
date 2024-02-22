import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatbot/components/backgroud.dart';
import 'package:chatbot/models/message_model.dart';
import 'package:chatbot/widget/conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:permission_handler/permission_handler.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final RecorderController recorderController;

  List<Message> savedMsg = [];
  bool isTyping = false;

  String? path;
  String? musicFile;
  bool isRecording = false;
  bool isRecordingCompleted = false;
  bool isLoading = true;
  late Directory appDirectory;
  final FlutterTts tts = FlutterTts();
  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();

  @override
  void initState() {
    super.initState();
    requestPermissions().then((_) {
      _getDir();
      _initialiseControllers();
    });
  }

  Future<void> requestPermissions() async {
    final status = await [Permission.microphone, Permission.storage].request();
    if (status[Permission.microphone]!.isGranted &&
        status[Permission.storage]!.isGranted) {
      print("Permissions granted");
    } else {
      print("Permissions denied");
    }
  }

  @override
  void dispose() {
    recorderController.dispose();
    super.dispose();
  }

  void _getDir() async {
    appDirectory = await path_provider.getApplicationDocumentsDirectory();

    //appDirectory = Directory('/storage/emulated/0/Download');
    path = "${appDirectory.path}/recording.m4a";
    isLoading = false;
    setState(() {});
  }

  void _initialiseControllers() {
    recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac // AAC는 널리 지원되는 안전한 선택입니다.
      ..androidOutputFormat = AndroidOutputFormat.mpeg4 // MPEG4는 널리 사용됩니다.
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC // iOS의 경우에도 동일합니다.
      ..sampleRate = 44100; // 44100Hz는 CD 품질의 오디오를 위한 표준 샘플레이트입니다.
  }

  Future<void> sendTextMessage(String text) async {
    var tempMessage = Message(false, "text", 'Typing...',
        DateFormat('kk:mm', 'ko').format(DateTime.now()));
    setState(() {
      savedMsg.insert(0, tempMessage);
      isTyping = true;
    });

    print('start send');
    var url = Uri.parse('http://210.125.31.148:80/infer/');
    var response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json', // JSON 형식으로 데이터를 보낸다고 서버에 알립니다.
      },
      body: json.encode({"input_text": text}),
    );
    if (response.statusCode == 307) {
      // Location 헤더에서 리디렉션 URL 가져오기
      var newUrl = response.headers['location'];
      if (newUrl != null) {
        // 새 URL로 다시 요청 보내기
        response = await http.post(
          Uri.parse(newUrl),
          headers: {
            'Content-Type': 'application/json', // JSON 형식으로 데이터를 보낸다고 서버에 알립니다.
          },
          body: json.encode({"input_text": text}),
        );
      }
    }
    if (response.statusCode == 200) {
      initializeDateFormatting('ko_KR', null);
      var now = DateTime.now();
      var time = DateFormat('kk:mm', 'ko').format(now).toString();
      // 요청이 성공했을 때 응답 처리
      var data = json.decode(response.body);
      final chatAnswer = data['result'].trim();
      await useTTS(chatAnswer);
      // setState(() {
      //   // 임시 메시지 제거
      //   savedMsg.removeAt(0);
      //   // savedMsg.insert(
      //   //   0,
      //   //   Message(false, 'text', chatAnswer, time),
      //   // );
      //   isTyping = false;
      // });

      print('answer: $chatAnswer'); // 서버로부터 받은 응답을 출력합니다.
    } else {
      // 서버로부터 200 외의 응답을 받았을 때 오류 처리
      print('Request failed with status: ${response.statusCode}.');
    }
  }

  Future<void> sendAudioMessage() async {
    var tempMessage = Message(false, "text", 'Typing...',
        DateFormat('kk:mm', 'ko').format(DateTime.now()));
    setState(() {
      savedMsg.insert(0, tempMessage);
      isTyping = true;
    });

    print('start send');

    var url = Uri.parse('http://210.125.31.150:80/whisper/infer');

    File audioFile = File(path!);
    String encodedData = base64Encode(audioFile.readAsBytesSync());
    var req = {
      "inputs": [
        {
          "name": "audio_url",
          "datatype": "BYTES",
          "shape": [1],
          "data": [encodedData]
        },
      ]
    };

    var jsonData = jsonEncode(req);
    var response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonData,
    );
    if (response.statusCode == 307) {
      // Location 헤더에서 리디렉션 URL 가져오기
      var newUrl = response.headers['location'];
      if (newUrl != null) {
        // 새 URL로 다시 요청 보내기
        response = await http.post(
          Uri.parse(newUrl),
          headers: {
            'Content-Type': 'application/json', // JSON 형식으로 데이터를 보낸다고 서버에 알립니다.
          },
          body: jsonData,
        );
      }
    }
    if (response.statusCode == 200) {
      print('answer: ${response.statusCode}');
      initializeDateFormatting('ko_KR', null);
      var now = DateTime.now();
      var time = DateFormat('kk:mm', 'ko').format(now).toString();
      // 요청이 성공했을 때 응답 처리
      var data = json.decode(response.body);

      var chatAnswer = (data['outputs'][0]['data'][0]);

      print('Decoded string: $chatAnswer');

      setState(() {
        //   // 임시 메시지 제거
        savedMsg.removeAt(0);
        //   savedMsg.insert(
        //     0,
        //     Message(false, 'text', chatAnswer, time),
        //   );
        //   isTyping = false;
      });
      await sendTextMessage(chatAnswer);
    } else {
      // 서버로부터 200 외의 응답을 받았을 때 오류 처리
      print('Request failed with status: ${response.statusCode}.');
    }
  }

  Future<void> useTTS(String chatAnswer) async {
    var url = Uri.parse('http://210.125.31.150:80/tts/infer');

    var req = {
      "inputs": [
        {
          "name": "text",
          "datatype": "BYTES",
          "shape": [1],
          "data": [chatAnswer]
        },
      ]
    };

    var jsonData = jsonEncode(req);
    var response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonData,
    );

    if (response.statusCode == 307) {
      // Location 헤더에서 리디렉션 URL 가져오기
      var newUrl = response.headers['location'];
      if (newUrl != null) {
        // 새 URL로 다시 요청 보내기
        response = await http.post(
          Uri.parse(newUrl),
          headers: {
            'Content-Type': 'application/json', // JSON 형식으로 데이터를 보낸다고 서버에 알립니다.
          },
          body: jsonData,
        );
      }
    }
    if (response.statusCode == 200) {
      initializeDateFormatting('ko_KR', null);
      var now = DateTime.now();
      var time = DateFormat('kk:mm', 'ko').format(now).toString();

      print('answer2: ${response.statusCode}');
      var data = json.decode(response.body);

      // 서버 응답에서 'data' 필드 추출
      var audioData = data['outputs'][0]['data'] as List<dynamic>;
// 'data' 필드의 내용을 List<double>로 변환
      List<double> fp32Array =
          audioData.map((e) => (e as num).toDouble()).toList();
      print(audioData.map((e) => e.runtimeType).toList());

// 변환된 fp32Array를 convertFP32ArrayToWavFile 함수에 전달
      var dir = await path_provider.getApplicationDocumentsDirectory();
      var filePath = "${dir.path}/recording.wav";

      saveFp32DataAsWav(fp32Array, filePath, 16000);
      //convertFP32ArrayToWavFile(fp32Array, filePath);
      //convertAudioToM4a(filePath,convertPath);

      setState(() {
        print('path = $filePath');
        savedMsg.removeAt(0);
        savedMsg.insert(0, Message(false, 'text', chatAnswer, time));
        setState(() {
          Conversation(
            msg: savedMsg,
          );
          isTyping = false;
        });
      });
    }
  }

  // FP32 오디오 데이터를 WAV 파일로 변환하고 저장하는 함수
  Future<void> saveFp32DataAsWav(
      List<double> fp32Data, String filePath, int sampleRate) async {
    // WAV 파일 헤더를 위한 바이트 데이터 생성
    ByteData byteData = ByteData(44 + fp32Data.length * 2); // 44 바이트 헤더 + 데이터
    var writer = ByteDataWriter(byteData);

    // RIFF 헤더 작성
    writer.writeString('RIFF');
    writer.writeInt32(byteData.lengthInBytes - 8,
        endianness: Endian.little); // 파일 크기
    writer.writeString('WAVE');

    // fmt 서브청크
    writer.writeString('fmt ');
    writer.writeInt32(16, endianness: Endian.little); // 서브청크1 크기: 16
    writer.writeInt16(1, endianness: Endian.little); // 오디오 포맷: PCM = 1
    writer.writeInt16(1, endianness: Endian.little); // 채널 수: 모노 = 1, 스테레오 = 2
    writer.writeInt32(sampleRate, endianness: Endian.little); // 샘플 속도
    writer.writeInt32(sampleRate * 2,
        endianness: Endian
            .little); // 바이트 속도: sampleRate * numChannels * bitsPerSample/8
    writer.writeInt16(2,
        endianness: Endian.little); // 블록 정렬: numChannels * bitsPerSample/8
    writer.writeInt16(16, endianness: Endian.little); // 샘플당 비트 수

    // data 서브청크
    writer.writeString('data');
    writer.writeInt32(fp32Data.length * 2, endianness: Endian.little); // 데이터 크기

    // FP32 데이터를 16비트 정수 형태로 변환하고 작성
    for (var sample in fp32Data) {
      int intSample =
          (sample * 32767.0).clamp(-32768, 32767).toInt(); // FP32를 16비트 정수로 변환
      writer.writeInt16(intSample, endianness: Endian.little);
    }

    // 파일에 바이트 데이터 작성
    File file = File(filePath);
    await file.writeAsBytes(byteData.buffer.asUint8List());
  }

  void convertFP32ArrayToWavFile(List<double> fp32Array, String filePath) {
    // WAV 파일 헤더 및 포맷 설정 (예제는 16비트 PCM, 모노, 44100Hz를 가정)
    int sampleRate = 44100;
    int bitsPerSample = 16;
    int numChannels = 1;
    int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    int blockAlign = numChannels * bitsPerSample ~/ 8;
    int dataSize = fp32Array.length * bitsPerSample ~/ 8;
    int fileSize = 36 + dataSize;

    // WAV 파일 헤더 작성
    ByteData header = ByteData(44);
    header.setUint32(0, 0x52494646, Endian.little); // 'RIFF'
    header.setUint32(4, fileSize, Endian.little);
    header.setUint32(8, 0x57415645, Endian.little); // 'WAVE'
    header.setUint32(12, 0x666d7420, Endian.little); // 'fmt '
    header.setUint32(16, 16, Endian.little); // PCM 청크 사이즈
    header.setUint16(20, 1, Endian.little); // 오디오 포맷 (1 = PCM)
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    header.setUint32(36, 0x64617461, Endian.little); // 'data'
    header.setUint32(40, dataSize, Endian.little);

    // FP32 데이터를 16비트 PCM 데이터로 변환
    Int16List pcmData = Int16List(fp32Array.length);
    for (int i = 0; i < fp32Array.length; i++) {
      int sample = (fp32Array[i] * 32767).toInt();
      pcmData[i] = sample.clamp(-32768, 32767);
    }

    // WAV 파일 생성 및 데이터 쓰기
    File file = File(filePath);
    file.writeAsBytesSync(header.buffer.asUint8List());
    file.writeAsBytesSync(pcmData.buffer.asUint8List(), mode: FileMode.append);
  }

  void convertAudioToM4a(String inputPath, String outputPath) {
    // '-y' 옵션은 출력 파일이 이미 존재할 경우 덮어쓰기를 의미합니다.
    // 입력 파일(inputPath)을 AAC 코덱을 사용하여 .m4a 파일로 변환합니다.
    _flutterFFmpeg
        .execute("-i $inputPath -c:a aac $outputPath -y")
        .then((returnCode) {
      if (returnCode == 0) {
        print("Audio conversion successful");
      } else {
        print("Audio conversion failed, return code: $returnCode");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    TextEditingController text = TextEditingController();

    return Scaffold(
      appBar: AppBar(
          backgroundColor: buttonColor,
          toolbarHeight: size.height * 0.1,
          centerTitle: false,
          title: Row(children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 30,
              backgroundImage: AssetImage('assets/chatbot.png'),
            ),
            SizedBox(
              width: 15,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI ChatBot',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold // 글씨 색상을 회색으로 설정
                        )),
                SizedBox(
                  height: 5,
                ),
                Text(
                  'Ask me anything',
                  style: TextStyle(
                    fontSize: 14, // 텍스트 크기를 14로 설정
                    color: Colors.white70, // 글씨 색상을 회색으로 설정
                  ),
                )
              ],
            )
          ]),
          elevation: 0),
      backgroundColor: buttonColor,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            Expanded(
                child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40))),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15)),
                child: Conversation(
                  msg: savedMsg,
                ),
              ),
            )),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 30, vertical: size.height * 0.020),
              color: Colors.white,
              height: size.height * 0.105,
              child: Row(
                children: [
                  if (!isTyping)
                    Expanded(
                      child: isRecording
                          ? AudioWaveforms(
                              enableGesture: true,
                              size: Size(
                                  MediaQuery.of(context).size.width / 2, 50),
                              recorderController: recorderController,
                              waveStyle: const WaveStyle(
                                waveColor: Colors.white,
                                extendWaveform: true,
                                showMiddleLine: false,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.0),
                                color: buttonColor,
                              ),
                              padding: const EdgeInsets.only(left: 18),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 15),
                            )
                          : Container(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              height: size.height * 0.5,
                              // margin: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(30)),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () async {},
                                    icon: Icon(
                                      Icons.file_copy_outlined,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: text,
                                      decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: 'Type the Message...',
                                          hintStyle: TextStyle(
                                              color: Colors.grey[500])),
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 30,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  SizedBox(width: size.width * 0.02),
                  CircleAvatar(
                    backgroundColor: buttonColor,
                    child: IconButton(
                      onPressed: () async {
                        if (!isTyping && !isRecording && !isLoading) {
                          initializeDateFormatting('ko_KR', null);
                          var now = DateTime.now();
                          var time =
                              DateFormat('kk:mm', 'ko').format(now).toString();
                          setState(() {
                            savedMsg.insert(
                                0, Message(true, 'text', text.text, time));
                            setState(() {
                              Conversation(
                                msg: savedMsg,
                              );
                            });
                          });
                          //real sendMessage
                          await sendTextMessage(text.text);
                          // test TTS
                          // await useTTS(text.text);
                        } else if (!isTyping && isRecording) {
                          _refreshWave();
                        }
                      },
                      icon: Icon(
                        isRecording ? Icons.refresh : Icons.send,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: size.width * 0.03,
                  ),
                  if (!isTyping)
                    CircleAvatar(
                      backgroundColor: buttonColor,
                      child: IconButton(
                        onPressed: _startOrStopRecording,
                        icon: Icon(isRecording ? Icons.stop : Icons.mic),
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            )
            //Container(child: ChatComposer(msg: msg,socket: socket,))
          ],
        ),
      ),
    );
  }

  void _startOrStopRecording() async {
    try {
      if (isRecording) {
        recorderController.reset();
        setState(() {
          isLoading = true;
        });
        final path = await recorderController.stop(false);

        if (path != null) {
          isRecordingCompleted = true;
          debugPrint(path);

          debugPrint("Recorded file size: ${File(path).lengthSync()}");
          initializeDateFormatting('ko_KR', null);
          var now = DateTime.now();
          var time = DateFormat('kk:mm', 'ko').format(now).toString();

          setState(() {
            savedMsg.insert(0, Message(true, 'audio', path, time));
            Conversation(
              msg: savedMsg,
            );
            isLoading = false;
          });
          await sendAudioMessage();
        }
      } else {
        await recorderController.record(path: path!);
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() {
        isRecording = !isRecording;
      });
    }
  }

  void _refreshWave() {
    if (isRecording) recorderController.refresh();
  }
}

class ByteDataWriter {
  final ByteData byteData;
  int _writePosition = 0;

  ByteDataWriter(this.byteData);

  void writeString(String value) {
    for (int i = 0; i < value.length; i++) {
      byteData.setUint8(_writePosition++, value.codeUnitAt(i));
    }
  }

  void writeInt32(int value, {Endian endianness = Endian.little}) {
    byteData.setInt32(_writePosition, value, endianness);
    _writePosition += 4;
  }

  void writeInt16(int value, {Endian endianness = Endian.little}) {
    byteData.setInt16(_writePosition, value, endianness);
    _writePosition += 2;
  }
}
