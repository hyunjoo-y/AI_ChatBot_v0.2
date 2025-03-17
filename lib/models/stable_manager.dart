import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StableManager {
  Future<String> convertTextToImage(String imageUrl, String prompt) async {
    //var imageBase64_ = "";
  
    final url = Uri.parse(imageUrl);

    // 요청 본문 데이터 설정
    var requestData = {
      "prompt":
          prompt,
      "negative_prompt":
          "",
      "seed": 1001,
      "height": 1024,
      "width": 1024,
      "scheduler": "KLMS",
      "num_inference_steps": 30,
      "guidance_scale": 10,
      "strength": 0.5,
      "num_images": 2
    };

    var jsonData = jsonEncode(requestData);
    var response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonData,
    );

    print("send Image req.");
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
          body: jsonEncode(requestData),
        );
      }
    }
    if (response.statusCode == 200) {
      try {
        final responseData = jsonDecode(response.body);
        List<dynamic> imageUrls = responseData['images'] as List<dynamic>;
        print("image URLs: $imageUrls");
        List<String> base64Images = [];

        for (var imageUrl in imageUrls) {
          var imageResponse = await http.get(Uri.parse(imageUrl));
          if (imageResponse.statusCode == 200) {
            var base64Image = base64Encode(imageResponse.bodyBytes);
            print("Base64 이미지: $base64Image");
            base64Images.add(base64Image);

            // 디코딩 시도 및 성공 여부 출력
            try {
              var decodedBytes = base64Decode(base64Image);
              var decodedImage =
                  await decodeImageFromList(Uint8List.fromList(decodedBytes));
              print(
                  '이미지 디코딩 성공: ${decodedImage.width} x ${decodedImage.height}');
            } catch (e) {
              print("이미지 디코딩 중 오류 발생: $e");
            }
          } else {
            print("이미지 가져오기 실패: ${imageResponse.statusCode}");
          }
        }

        // Base64 문자열을 콤마로 결합하여 반환
        return base64Images.join(',');
      } on Exception catch (e) {
        print("데이터 처리 실패: $e");
        return '';
      }
    } else {
      print("요청에 실패했습니다. 상태 코드: ${response.statusCode}");
      return '${response.statusCode}';
    }
  }
}
