import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatbot/components/backgroud.dart';
import 'package:chatbot/models/chatroom_model.dart';
import 'package:chatbot/models/database_service.dart';
import 'package:chatbot/models/message_model.dart';
import 'package:chatbot/models/stable_manager.dart';
import 'package:chatbot/page/chat_datail_screen.dart';
import 'package:chatbot/widget/conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final RecorderController recorderController;
  TextEditingController textController = TextEditingController();
  final DBHelper _dbHelper = DBHelper();
  List<ChatRoom> _chatrooms = [];
  List<Message> _messages = [];

  List<Message> savedMsg = [];
  bool isTyping = false;
  bool isChatBotAnswer = false;

  String? path;
  String? musicFile;
  bool isRecording = false;
  bool isRecordingCompleted = false;
  bool isLoading = true;
  late Directory appDirectory;
  final FlutterTts tts = FlutterTts();
  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();

  String _displayedText = '';
  String _content = '';
  int _currentCharIndex = 0;
  Timer? _timer;
  Timer? _loadingTimer;
  bool _isPaused = false;
  int _pausedIndex = 0;

  String? _image;
  FocusNode _focusNode = FocusNode();
  bool isButtonVisible = true; // 추가된 상태 변수
  ChatRoom? _currentChatroom;

  DateTime? _lastPressedAt; // 마지막으로 뒤로가기 버튼을 누른 시간

  var textUrl = "http://";
  var imageUrl = "http://";

  var audioUrl = "http://";

  @override
  void initState() {
    super.initState();
    _currentChatroom = ChatRoom(id: "default", name: "default");
    _initDatabase();
    _loadEndpoints();
    _focusNode = FocusNode();
    requestPermissions().then((_) {
      _getDir();
      _initialiseControllers();
    });
  }

  Future<void> _initDatabase() async {
    await _dbHelper.database; // Ensure the database is initialized
    _loadChatrooms();
  }

  Future<void> _loadChatrooms() async {
    final chatrooms = await _dbHelper.fetchChatrooms();
    setState(() {
      _chatrooms = chatrooms;

      print('chatroom name: ${_chatrooms[0].name}');
    });
  }

  Future<bool> _onWillPop() async {
    if (_lastPressedAt == null ||
        DateTime.now().difference(_lastPressedAt!) > Duration(seconds: 1)) {
      // 2초 내에 다시 누르지 않으면 경고 메시지 출력
      _lastPressedAt = DateTime.now();

      Fluttertoast.showToast(
          msg: "Press back again to exit",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: list1,
          textColor: Colors.grey,
          fontSize: 16.0);
      return false;
    }
    return true;
  }

  void _addChatRoom() {
    if (isTyping) {
      setState(() {
        isTyping = false;
      });
    }
    if (savedMsg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'No messages in the current chat room to create a new chat room.')),
      );
      return;
    }

    setState(() {
      savedMsg = [];
      _currentChatroom = ChatRoom(id: "default", name: "default");
    });
    //Navigator.of(context).pop();
    // Navigate to the new chat room
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => ChatPage(),
    //   ),
    // );
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
    _timer?.cancel();
    _focusNode.dispose();
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
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;
  }

  String _loadingText = 'T';

  void _startLoadingAnimation() {
    const loadingSteps = ['T', 'Ty', 'Typ', 'Typi', 'Typin', 'Typing...'];
    int index = 0;
    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(Duration(milliseconds: 400), (timer) {
      setState(() {
        _loadingText = loadingSteps[index];
        savedMsg[0] = Message(false, 'loading', _loadingText,
            DateFormat('kk:mm', 'ko').format(DateTime.now()));
      });
      index = (index + 1) % loadingSteps.length;
    });
  }

  void _stopLoadingAnimation() {
    _loadingTimer?.cancel();
    setState(() {
      isTyping = false;
      // if (savedMsg.isNotEmpty && savedMsg[0].content.startsWith('T')) {
      //   savedMsg.removeAt(0);
      // }
    });
  }

  Future<void> _startAddingCharacters(String content, String time) async {
    isChatBotAnswer = true;
    _content = content;
    const duration = Duration(milliseconds: 150);
    _timer?.cancel();
    _currentCharIndex = _isPaused ? _pausedIndex : 0;
    _displayedText = _isPaused ? _content.substring(0, _pausedIndex) : '';
    setState(() {
      isTyping = true;
    });

    if (!_isPaused) {
      if (savedMsg.isNotEmpty && savedMsg[0].type == 'loading') {
        savedMsg.removeAt(0);
      }

      savedMsg.insert(0, Message(false, 'text', '', time));
    }

    _timer = Timer.periodic(duration, (Timer timer) async {
      if (_currentCharIndex < _content.length) {
        setState(() {
          _displayedText = _content.substring(0, _currentCharIndex + 1);
          savedMsg[0] = Message(false, 'text', _displayedText, time);
          _currentCharIndex++;
        });
      } else {
        timer.cancel();
        await _dbHelper.insertMessage(_currentChatroom!.id, savedMsg[0]);
        print(
            'check database chatL: ${savedMsg[0].content} ${savedMsg[0].timestamp}');
        setState(() {
          isTyping = false;
          _isPaused = false;
          _content = '';
        });
      }
    });
  }

  void pauseTyping() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (isChatBotAnswer) {
        setState(() {
          _timer?.cancel();
          _isPaused = true;
          isTyping = false;
          _pausedIndex = _currentCharIndex;
          isChatBotAnswer = false;
          _content = '';
        });

        await _dbHelper.insertMessage(_currentChatroom!.id, savedMsg[0]);
      } else {
        _stopLoadingAnimation();
        setState(() {
          savedMsg.removeAt(0);
        });
      }
    });
  }

  Future<bool> _canConnectToURL(String url) async {
    try {
      final uri = Uri.parse(url);
      final result = await InternetAddress.lookup(uri.host);
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (e) {
      print('Error: $e');
    }
    return false;
  }

  Future<void> sendTextMessage(String text) async {
    if (!await _canConnectToURL(textUrl)) {
      Fluttertoast.showToast(
          msg: 'Cannot connect to $textUrl',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: toast,
          textColor: Colors.black,
          fontSize: 20.0);

      return;
    }

    // 임시 로딩 메시지 추가
    var tempMessage = Message(false, "loading", 'T',
        DateFormat('kk:mm', 'ko').format(DateTime.now()));
    setState(() {
      savedMsg.insert(0, tempMessage);
      isTyping = true;
    });
    _startLoadingAnimation();

    print('start send');

    // url = Uri.parse(
    //     'http://219.251.253.167:8889/vllm_korean/v1/chat/completions');

    /*var req = {
      "input_text": text,
      "user_id": "sslab",
      "history": "",
      "fault_test": false
    };
*/

    var req = {
      "model": "Copycats/EEVE-Korean-Instruct-10.8B-v1.0-AWQ",
      "messages": [
        {
          "role": "system",
          "content":
              "You are a helpful and knowledgeable assistant. Provide accurate, clear, and friendly responses to user queries."
        },
        {"role": "user", "content": text}
      ],
      "temperature": 0.1,
      "min_tokens": 100,
      "max_tokens": 500,
      "stream": false
    };

    print('text URL: $textUrl');

    var jsonData = jsonEncode(req);
    var response = await http.post(
      Uri.parse(textUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonData,
    );

    print('post send');

    /*var response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({"input_text": text}),
    );*/
    if (response.statusCode == 307) {
      // Location 헤더에서 리디렉션 URL 가져오기
      var newUrl = response.headers['location'];
      if (newUrl != null) {
        // 새 URL로 다시 요청 보내기
        response = await http.post(
          Uri.parse(newUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonData,
        );
      }
    }
    if (response.statusCode == 200) {
      initializeDateFormatting('ko_KR', null);
      var now = DateTime.now();
      var time = DateFormat('kk:mm', 'ko').format(now);
      // 요청이 성공했을 때 응답 처리
      //var data = json.decode(response.body);
      var data = json.decode(utf8.decode(response.bodyBytes));
      final chatAnswer = data['choices'][0]['message']['content'];

      _stopLoadingAnimation(); // 로딩 애니메이션 중지
      setState(() {
        savedMsg.insert(
          0,
          Message(false, 'text', chatAnswer, time),
        );
      });

      _startAddingCharacters(chatAnswer, time);

      print('answer: $chatAnswer'); // 서버로부터 받은 응답을 출력합니다.
      // final chatAnswer = data['result'].trim();
      // await useTTS(chatAnswer);
      // setState(() {
      //   //   // 임시 메시지 제거
      //   savedMsg.removeAt(0);
      //   savedMsg.insert(
      //     0,
      //     Message(false, 'text', chatAnswer, time),
      //   );
      //   isTyping = false;
      // });

      print('answer: $chatAnswer'); // 서버로부터 받은 응답을 출력합니다.
    } else {
      _stopLoadingAnimation(); // 로딩 애니메이션 중지
      // 서버로부터 200 외의 응답을 받았을 때 오류 처리
      setState(() {
        isTyping = false;
        savedMsg.removeAt(0);
      });

      Fluttertoast.showToast(
          msg: 'Request failed with status: ${response.statusCode}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: toast,
          textColor: Colors.black,
          fontSize: 20.0);

      print('Request failed with status: ${response.statusCode}.');
    }
  }

  bool _isValidURL(String url) {
    return Uri.tryParse(url)?.hasAbsolutePath ?? false;
  }

  Future<void> _saveEndpoints(String textUrl, String imageUrl) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('textUrl', textUrl);
    await prefs.setString('imageUrl', imageUrl);
  }

  Future<void> _loadEndpoints() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      textUrl = prefs.getString('textUrl') ?? "http://";
      imageUrl = prefs.getString('imageUrl') ?? "http://";
    });
  }

  void _showEndpointInputDialog(BuildContext context) {
    String llmUrl = textUrl;
    String imageModelEndpointUrl = imageUrl;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Endpoints'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEndpointField('LLM Endpoint', llmUrl, (value) {
                llmUrl = value;
              }),
              SizedBox(height: 10),
              _buildEndpointField('Image Model Endpoint', imageModelEndpointUrl,
                  (value) {
                imageModelEndpointUrl = value;
              }),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // 닫기만 하고 아무 작업도 하지 않음
              },
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () {
                if ((llmUrl == "http://" || llmUrl.isEmpty) ||
                    (imageModelEndpointUrl == "http://" ||
                        imageModelEndpointUrl.isEmpty)) {
                  Fluttertoast.showToast(
                      msg: 'Please enter both Endpoints',
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.CENTER,
                      timeInSecForIosWeb: 1,
                      backgroundColor: toast,
                      textColor: Colors.black,
                      fontSize: 20.0);
                }
                //  else if (!_isValidURL(llmUrl) ||
                //     !_isValidURL(imageModelEndpointUrl)) {
                //   Fluttertoast.showToast(
                //       msg: 'Please enter valid Endpoints',
                //       toastLength: Toast.LENGTH_SHORT,
                //       gravity: ToastGravity.CENTER,
                //       timeInSecForIosWeb: 1,
                //       backgroundColor: toast,
                //       textColor: Colors.black,
                //       fontSize: 20.0);
                // }
                else {
                  setState(() {
                    textUrl = llmUrl;
                    imageUrl = imageModelEndpointUrl;
                    _saveEndpoints(textUrl, imageUrl); // URL 저장
                  });

                  // Handle llmUrl and imageModelEndpointUrl here
                  print('LLM URL entered: $llmUrl');
                  print(
                      'Image Model Endpoint URL entered: $imageModelEndpointUrl');
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildEndpointField(
      String label, String initialValue, ValueChanged<String> onChanged) {
    return TextField(
      onChanged: onChanged,
      controller: TextEditingController(text: initialValue),
      decoration: InputDecoration(
        hintText: 'Enter $label',
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }

  Future<void> sendImageRequest(String text) async {
    if (!await _canConnectToURL(imageUrl)) {
      Fluttertoast.showToast(
          msg: 'Cannot connect to $imageUrl',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: toast,
          textColor: Colors.black,
          fontSize: 20.0);

      return;
    }
    var tempMessage = Message(false, "loading", 'T',
        DateFormat('kk:mm', 'ko').format(DateTime.now()));
    setState(() {
      savedMsg.insert(0, tempMessage);
      isTyping = true;
    });

    _startLoadingAnimation();

    // _image = await StableManager().convertTextToImage(text);
    String images = await StableManager().convertTextToImage(imageUrl, text);
    _stopLoadingAnimation(); // 로딩 애니메이션 중지
    if (!images.contains(',')) {
      setState(() {
        isTyping = false;
        savedMsg.removeAt(0);
      });

      Fluttertoast.showToast(
          msg: 'Request failed with status: $images',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: toast,
          textColor: Colors.black,
          fontSize: 20.0);
    } else {
      setState(() {
        //   // 임시 메시지 제거
        savedMsg.removeAt(0);
        savedMsg.insert(
          0,
          Message(false, 'image', images,
              DateFormat('kk:mm', 'ko').format(DateTime.now())),
        );
        isTyping = false;
      });
      print("get image: ${_currentChatroom!.id}");
      await _dbHelper.insertMessage(_currentChatroom!.id, savedMsg[0]);
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

    var url = Uri.parse(
        'http://172.21.3.100:3000/v2/models/whisper/infer');

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
      //Uri.parse(audioUrl),
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
      });
      await sendTextMessage(chatAnswer);
    } else {
      // 서버로부터 200 외의 응답을 받았을 때 오류 처리
      print('Request failed with status: ${response.statusCode}.');
    }
  }

  Future<void> useTTS(String chatAnswer) async {
    print('chat Anser: $chatAnswer');
    // url =
    //     Uri.parse('http://210.125.31.176:6000/provider/Prov/model/tts/1/infer');

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
      Uri.parse(audioUrl),
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
            isTyping: isTyping,
            pauseTyping: pauseTyping,
            chatRoom_id: _currentChatroom!.id,
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

  void _switchChatroom(ChatRoom chatroom) {
    setState(() {
      _currentChatroom = chatroom;
      savedMsg = [];
    });
    _loadMessages();
    Navigator.of(context).pop(); // close the drawer
  }

  Future<void> _loadMessages() async {
    final fetchedMessages = await _dbHelper.fetchMessages(_currentChatroom!.id);
    setState(() {
      savedMsg = fetchedMessages;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: Icon(Icons.add_outlined),
              onPressed: () {
                textController.clear();
                _addChatRoom();
              },
            ),
          ],
          backgroundColor: list1, //buttonColor,
          toolbarHeight: size.height * 0.1,
          centerTitle: false,
          title: GestureDetector(
            onTap: () {
              _showEndpointInputDialog(context);
            },
            child: Row(children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 30,
                backgroundImage: AssetImage('assets/aieev.jpeg'),
              ),
              SizedBox(
                width: 15,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aieev Assistant',
                      style: TextStyle(
                          fontSize: 22,
                          color: Color(0xFF4B0082),
                          fontWeight: FontWeight.bold // 글씨 색상을 회색으로 설정
                          )),
                  SizedBox(
                    height: 5,
                  ),
                  Text(
                    'I\'m here to help you.',
                    style: TextStyle(
                        fontSize: 14, // 텍스트 크기를 14로 설정
                        color: Color(0xFF696969)
                        // color: Colors.white70, // 글씨 색상을 회색으로 설정
                        ),
                  )
                ],
              )
            ]),
          ),
          elevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: const Color.fromARGB(255, 233, 232, 232),
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              SizedBox(
                height: size.height * 0.05,
              ),
              ListTile(
                title: Text('Chat History',
                    style:
                        TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
              ),
              Container(
                height: size.height * 0.05,
                child: ListTile(
                  title: Text('Recent Chat',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              ..._chatrooms
                  .map((chatroom) => ListTile(
                        title: Text(
                          chatroom.name,
                          style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: Colors.grey),
                        ),
                        //   subtitle: Text(msg.timestamp),
                        onTap: () {
                          // Navigator.pop(context); // Drawer 닫기
                          _switchChatroom(chatroom); // 채팅방 전환
                        },
                        onLongPress: () async {
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text("Delete Confirmation"),
                                content: Text(
                                    "Are you sure you want to delete this room?"),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.of(context).pop(true);
                                      _dbHelper.deleteChatroom(chatroom.id);
                                      final chatrooms =
                                          await _dbHelper.fetchChatrooms();

                                      setState(() {
                                        _currentChatroom = ChatRoom(
                                            id: "default", name: "default");
                                        _chatrooms = chatrooms;
                                        savedMsg = [];
                                      });
                                    },
                                    child: Text("Delete"),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ))
                  .toList(),
            ],
          ),
        ),

        // DrawerHeader(
        //   child: Text('Chat History',
        //       style:
        //           TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        //   decoration: BoxDecoration(
        //     color: Colors.white,
        //   ),
        // ),
        backgroundColor: list1,
        body: GestureDetector(
          onTap: () {
            // 화면 밖을 터치하면 키보드가 내려가도록 설정
            FocusScope.of(context).unfocus();
          },
          child: Column(
            children: [
              Expanded(
                  child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
                    isTyping: isTyping,
                    pauseTyping: pauseTyping,
                    chatRoom_id: _currentChatroom!.id,
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
                                  color: list1,
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
                                      onPressed: () async {
                                        initializeDateFormatting('ko_KR', null);
                                        var now = DateTime.now();
                                        var time = DateFormat('kk:mm', 'ko')
                                            .format(now)
                                            .toString();

                                        if (savedMsg.length == 0) {
                                          final chatroomName =
                                              textController.text.substring(
                                                  0,
                                                  textController.text.length <
                                                          15
                                                      ? textController
                                                          .text.length
                                                      : 15);
                                          final newChatroom = ChatRoom(
                                              id: DateTime.now()
                                                  .millisecondsSinceEpoch
                                                  .toString(),
                                              name: chatroomName);
                                          setState(() {
                                            _currentChatroom = newChatroom;
                                          });

                                          await _dbHelper
                                              .createChatroom(newChatroom);

                                          final chatrooms =
                                              await _dbHelper.fetchChatrooms();

                                          setState(() {
                                            _chatrooms = chatrooms;
                                          });
                                        }

                                        await _dbHelper.insertMessage(
                                            _currentChatroom!.id,
                                            Message(true, 'text',
                                                textController.text, time));

                                        setState(() {
                                          savedMsg.insert(
                                              0,
                                              Message(true, 'text',
                                                  textController.text, time));
                                          setState(() {
                                            Conversation(
                                              msg: savedMsg,
                                              isTyping: isTyping,
                                              pauseTyping: pauseTyping,
                                              chatRoom_id: _currentChatroom!.id,
                                            );
                                          });
                                        });

                                        textController.clear();
                                        await sendImageRequest(
                                            textController.text);
                                      },
                                      icon: Icon(
                                        Icons.image,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    Expanded(
                                      child: TextField(
                                        focusNode: _focusNode,
                                        controller: textController,
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
                      backgroundColor: list1,
                      child: IconButton(
                        onPressed: () async {
                          if (!isTyping && !isRecording && !isLoading) {
                            initializeDateFormatting('ko_KR', null);
                            var now = DateTime.now();
                            var time = DateFormat('kk:mm', 'ko')
                                .format(now)
                                .toString();
                            var database_time = DateFormat('kk:mm:ss', 'ko')
                                .format(now)
                                .toString();
                            if (savedMsg.length == 0) {
                              final chatroomName = textController.text
                                  .substring(
                                      0,
                                      textController.text.length < 15
                                          ? textController.text.length
                                          : 15);
                              final newChatroom = ChatRoom(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  name: chatroomName);
                              _currentChatroom = newChatroom;
                              await _dbHelper.createChatroom(newChatroom);
                              final chatrooms =
                                  await _dbHelper.fetchChatrooms();

                              setState(() {
                                _chatrooms = chatrooms;
                              });
                            }
                            print('check database chat: ${time}');
                            await _dbHelper.insertMessage(
                                _currentChatroom!.id,
                                Message(
                                    true, 'text', textController.text, time));

                            setState(() {
                              savedMsg.insert(
                                  0,
                                  Message(
                                      true, 'text', textController.text, time));

                              setState(() {
                                Conversation(
                                  msg: savedMsg,
                                  isTyping: isTyping,
                                  pauseTyping: pauseTyping,
                                  chatRoom_id: _currentChatroom!.id,
                                );
                              });
                            });
                            // await _databaseService.insertMessage(savedMsg[0]);
                            //real sendMessage
                            textController.clear();

                            await sendTextMessage(textController.text);

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
                        backgroundColor: list1,
                        child: IconButton(
                          onPressed: () => {_startOrStopRecording}, //_startOrStopRecording,
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
              isTyping: isTyping,
              pauseTyping: pauseTyping,
              chatRoom_id: _currentChatroom!.id,
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
