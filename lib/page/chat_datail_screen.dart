import 'package:flutter/material.dart';
import 'package:chatbot/models/message_model.dart';
import 'dart:io';

class ChatDetailScreen extends StatefulWidget {
  final List<Message> messages;

  const ChatDetailScreen({Key? key, required this.messages}) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Details'),
      ),
      body: ListView.builder(
        itemCount: widget.messages.length,
        itemBuilder: (context, index) {
          final message = widget.messages[index];
          return ListTile(
            title: message.type == 'text' ? Text(message.content) : Image.file(File(message.content)),
            subtitle: Text(message.timestamp),
            leading: message.sender ? Icon(Icons.person) : Icon(Icons.computer),
          );
        },
      ),
    );
  }
}
