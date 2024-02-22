import 'package:chatbot/page/chat_page.dart';
import 'package:flutter/material.dart';

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
