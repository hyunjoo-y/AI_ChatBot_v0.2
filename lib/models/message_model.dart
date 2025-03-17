import 'package:intl/intl.dart';

class Message {
  bool sender; // true if the message is sent by the user
  String type; // type of the message, e.g., "text", "image"
  String content; // content of the message, could be text or image URL
  String timestamp; // timestamp of the message

  Message(this.sender, this.type, this.content, this.timestamp);

  Map<String, dynamic> toMap() {
    return {
      'sender': sender
          ? 1
          : 0, // store as integer in database (1 for true, 0 for false)
      'type': type,
      'content': content,
      'timestamp': timestamp,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      map['sender'] == 1, // convert back to bool
      map['type'],
      map['content'],
      map['timestamp'],
    );
  }

  String get formattedTimestamp {
    final dateTime = DateTime.parse(timestamp);
    final formatter = DateFormat('kk:mm'); // Format to hours and minutes
    return formatter.format(dateTime);
  }
}
