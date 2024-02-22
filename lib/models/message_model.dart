class Message {
  bool isMe;
  String type; 
  String content;
  String timestamp;

  Message(
      this.isMe, this.type, this.content, this.timestamp);

  Map<String, dynamic> toMap() {
    return {
      'sender': isMe,
      'type': type,
      'message': content,
      'timestamp': timestamp,
    };
  }
/*
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      sender: frUser.fromMap(map['sender']),
      receiver: frUser.fromMap(map['receiver']),
      message: map['message'],
      timestamp: map['timestamp'],
    );
  }*/
}
