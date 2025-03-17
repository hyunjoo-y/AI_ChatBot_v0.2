import 'dart:convert'; // JSON 인코딩을 위해 필요
import 'dart:io'; // 인터넷 주소 조회를 위해 필요
import 'package:chatbot/models/stable_manager.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart'; // Fluttertoast를 위해 필요
import 'package:http/http.dart' as http; // HTTP 요청을 위해 필요
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences를 위해 필요

class ApiService {
  var textUrl = "http://";
  var imageUrl = "http://";

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

  Future<void> sendTextMessage(String text, Map<String, dynamic> req) async {
    if (!await _canConnectToURL(textUrl)) {
      Fluttertoast.showToast(
          msg: 'Cannot connect to $textUrl',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.blue,
          textColor: Colors.black,
          fontSize: 20.0);

      return;
    }

    print('text URL: $textUrl');

    var jsonData = jsonEncode(req);
    var response = await http.post(
      Uri.parse(textUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonData,
    );

    print('post send');

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
      // 요청이 성공했을 때 응답 처리
      var data = json.decode(utf8.decode(response.bodyBytes));
      final answer = data['choices'][0]['message']['content'];

      Fluttertoast.showToast(
          msg: 'Request failed with status: ${response.statusCode}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.blue,
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

    textUrl = prefs.getString('textUrl') ?? "http://";
    imageUrl = prefs.getString('imageUrl') ?? "http://";
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
                Navigator.of(context).pop();
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
                      backgroundColor: Colors.blue,
                      textColor: Colors.black,
                      fontSize: 20.0);
                } else {
                  _saveEndpoints(textUrl, imageUrl); // URL 저장
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

  Future<String?> sendImageRequest(
      String text, Map<String, dynamic> req) async {
    if (!await _canConnectToURL(imageUrl)) {
      Fluttertoast.showToast(
        msg: 'Cannot connect to $imageUrl',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.blue,
        textColor: Colors.black,
        fontSize: 20.0,
      );

      return null;
    }

    try {
      String images =
          await StableManager().convertTextToImage(imageUrl, text);

      Fluttertoast.showToast(
        msg: 'Request succeeded with status: $images',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.blue,
        textColor: Colors.black,
        fontSize: 20.0,
      );

      return images;
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Request failed with error: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.black,
        fontSize: 20.0,
      );

      return null;
    }
  }
}
