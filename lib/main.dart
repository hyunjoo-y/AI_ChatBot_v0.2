import 'package:chatbot/page/chat_page.dart';
import 'package:flutter/material.dart';

import 'page/splash_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SplashScreen(), // 스플래시 스크린을 첫 화면으로 설정
    );
  }
}

/*
void main() {
   runApp(const MainApp(chatPage: ChatPage(),));
}

class MainApp extends StatelessWidget {
  const MainApp({Key? key, required this.chatPage}) : super(key: key);

  final Widget chatPage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blockchain Messenger',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        body: chatPage,
      ),
    );
  }
}
*/