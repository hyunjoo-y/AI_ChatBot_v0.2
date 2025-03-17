// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// import 'package:shared_preferences/shared_preferences.dart';

// class MyWidget extends StatefulWidget {
//   const MyWidget({super.key});

//   @override
//   State<MyWidget> createState() => _MyWidgetState();
// }

// class _MyWidgetState extends State<MyWidget> {
//   var textUrl = "http://";
//   var imageUrl = "http://";

//   TextEditingController textController = TextEditingController();

//    @override
//   void initState() {
//     super.initState();
//     _loadEndpoints();
//   }


//   Future<bool> _canConnectToURL(String url) async {
//     try {
//       final uri = Uri.parse(url);
//       final result = await InternetAddress.lookup(uri.host);
//       if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
//         return true;
//       }
//     } catch (e) {
//       print('Error: $e');
//     }
//     return false;
//   }

//   Future<void> sendTextMessage(String text, Map<String, dynamic> req) async {
//     if (!await _canConnectToURL(textUrl)) {
//       Fluttertoast.showToast(
//           msg: 'Cannot connect to $textUrl',
//           toastLength: Toast.LENGTH_SHORT,
//           gravity: ToastGravity.CENTER,
//           timeInSecForIosWeb: 1,
//           backgroundColor: Colors.blue,
//           textColor: Colors.black,
//           fontSize: 20.0);

//       return;
//     }

//     print('text URL: $textUrl');

//     var jsonData = jsonEncode(req);
//     var response = await http.post(
//       Uri.parse(textUrl),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonData,
//     );

//     print('post send');

//     /*var response = await http.post(
//       url,
//       headers: {
//         'Content-Type': 'application/json',
//       },
//       body: json.encode({"input_text": text}),
//     );*/
//     if (response.statusCode == 307) {
//       // Location 헤더에서 리디렉션 URL 가져오기
//       var newUrl = response.headers['location'];
//       if (newUrl != null) {
//         // 새 URL로 다시 요청 보내기
//         response = await http.post(
//           Uri.parse(newUrl),
//           headers: {
//             'Content-Type': 'application/json',
//           },
//           body: jsonData,
//         );
//       }
//     }
//     if (response.statusCode == 200) {
//       // 요청이 성공했을 때 응답 처리
//       var data = json.decode(utf8.decode(response.bodyBytes));
//       final answer = data['choices'][0]['message']['content'];

//       Fluttertoast.showToast(
//           msg: 'Request failed with status: ${response.statusCode}',
//           toastLength: Toast.LENGTH_SHORT,
//           gravity: ToastGravity.CENTER,
//           timeInSecForIosWeb: 1,
//           backgroundColor: Colors.blue,
//           textColor: Colors.black,
//           fontSize: 20.0);

//       print('Request failed with status: ${response.statusCode}.');
//     }
//   }

//   bool _isValidURL(String url) {
//     return Uri.tryParse(url)?.hasAbsolutePath ?? false;
//   }

//   Future<void> _saveEndpoints(String textUrl, String imageUrl) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.setString('textUrl', textUrl);
//     await prefs.setString('imageUrl', imageUrl);
//   }

//   Future<void> _loadEndpoints() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     setState(() {
//       textUrl = prefs.getString('textUrl') ?? "http://";
//       imageUrl = prefs.getString('imageUrl') ?? "http://";
//     });
//   }

//   void _showEndpointInputDialog(BuildContext context) {
//     String llmUrl = textUrl;
//     String imageModelEndpointUrl = imageUrl;

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Enter Endpoints'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               _buildEndpointField('LLM Endpoint', llmUrl, (value) {
//                 llmUrl = value;
//               }),
//               SizedBox(height: 10),
//               _buildEndpointField('Image Model Endpoint', imageModelEndpointUrl,
//                   (value) {
//                 imageModelEndpointUrl = value;
//               }),
//             ],
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop(); // 닫기만 하고 아무 작업도 하지 않음
//               },
//             ),
//             TextButton(
//               child: Text('OK'),
//               onPressed: () {
//                 if ((llmUrl == "http://" || llmUrl.isEmpty) ||
//                     (imageModelEndpointUrl == "http://" ||
//                         imageModelEndpointUrl.isEmpty)) {
//                   Fluttertoast.showToast(
//                       msg: 'Please enter both Endpoints',
//                       toastLength: Toast.LENGTH_SHORT,
//                       gravity: ToastGravity.CENTER,
//                       timeInSecForIosWeb: 1,
//                       backgroundColor: Colors.blue,
//                       textColor: Colors.black,
//                       fontSize: 20.0);
//                 }
//                 else {
//                   setState(() {
//                     textUrl = llmUrl;
//                     imageUrl = imageModelEndpointUrl;
//                     _saveEndpoints(textUrl, imageUrl); // URL 저장
//                   });

//                   // Handle llmUrl and imageModelEndpointUrl here
//                   print('LLM URL entered: $llmUrl');
//                   print(
//                       'Image Model Endpoint URL entered: $imageModelEndpointUrl');
//                   Navigator.of(context).pop();
//                 }
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildEndpointField(
//       String label, String initialValue, ValueChanged<String> onChanged) {
//     return TextField(
//       onChanged: onChanged,
//       controller: TextEditingController(text: initialValue),
//       decoration: InputDecoration(
//         hintText: 'Enter $label',
//         labelText: label,
//         border: OutlineInputBorder(),
//       ),
//     );
//   }

//   Future<void> sendImageRequest(String text) async {
//     if (!await _canConnectToURL(imageUrl)) {
//       Fluttertoast.showToast(
//           msg: 'Cannot connect to $imageUrl',
//           toastLength: Toast.LENGTH_SHORT,
//           gravity: ToastGravity.CENTER,
//           timeInSecForIosWeb: 1,
//           backgroundColor: toast,
//           textColor: Colors.black,
//           fontSize: 20.0);

//       return;
//     }
//     var tempMessage = Message(false, "loading", 'T',
//         DateFormat('kk:mm', 'ko').format(DateTime.now()));
//     setState(() {
//       savedMsg.insert(0, tempMessage);
//       isTyping = true;
//     });

//     _startLoadingAnimation();

//     // _image = await StableManager().convertTextToImage(text);
//     String images = await StableManager().convertTextToImage(imageUrl, text);
//     _stopLoadingAnimation(); // 로딩 애니메이션 중지
//     if (!images.contains(',')) {
//       setState(() {
//         isTyping = false;
//         savedMsg.removeAt(0);
//       });

//       Fluttertoast.showToast(
//           msg: 'Request failed with status: $images',
//           toastLength: Toast.LENGTH_SHORT,
//           gravity: ToastGravity.CENTER,
//           timeInSecForIosWeb: 1,
//           backgroundColor: toast,
//           textColor: Colors.black,
//           fontSize: 20.0);
//     } else {
//       setState(() {
//         //   // 임시 메시지 제거
//         savedMsg.removeAt(0);
//         savedMsg.insert(
//           0,
//           Message(false, 'image', images,
//               DateFormat('kk:mm', 'ko').format(DateTime.now())),
//         );
//         isTyping = false;
//       });
//       print("get image: ${_currentChatroom!.id}");
//       await _dbHelper.insertMessage(_currentChatroom!.id, savedMsg[0]);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return CircleAvatar(
//         child: IconButton(
//       onPressed: () async {

//         // example 용
//         var req = {
//           "model": "Copycats/EEVE-Korean-Instruct-10.8B-v1.0-AWQ",
//           "messages": [
//             {
//               "role": "system",
//               "content":
//                   "You are a helpful and knowledgeable assistant. Provide accurate, clear, and friendly responses to user queries."
//             },
//             {"role": "user", "content": textController.text}
//           ],
//           "temperature": 0.1,
//           "min_tokens": 100,
//           "max_tokens": 500,
//           "stream": false
//         };

//         await sendTextMessage(
//           textController.text, req
//         );

//         // test TTS
//         // await useTTS(text.text);
//       },
//       icon: Icon(
//         Icons.send,
//         color: Colors.white,
//       ),
//     ));
//   }
// }
