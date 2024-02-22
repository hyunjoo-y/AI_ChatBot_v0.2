import 'package:audioplayers/audioplayers.dart';
import 'package:chatbot/components/backgroud.dart';
import 'package:chatbot/models/message_model.dart';
import 'package:chatbot/models/wave_model.dart';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

class Conversation extends StatefulWidget {
  final List<Message> msg;
  const Conversation({super.key, required this.msg});

  @override
  State<Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<Conversation> {
  late String filePath;

  @override
  void initState() {
    super.initState();
    getPath();
  }

  void getPath() async {
    var dir = await path_provider.getApplicationDocumentsDirectory();
    filePath = "${dir.path}/recording.wav";
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final audioPlayer = AudioPlayer();

    return ListView.builder(
        reverse: true,
        itemCount: widget.msg.length,
        itemBuilder: (context, int index) {
          final message = widget.msg[index];

          bool isMe = message.isMe == true;
          bool isAudio = message.type == 'audio';
          bool isTyping = message.content == 'Typing...';

          return Container(
              margin: EdgeInsets.only(top: 10),
              child: Column(
                children: [
                  Row(
                      mainAxisAlignment: isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isMe)
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 15,
                            backgroundImage: AssetImage('assets/chatbot.png'),
                          ),
                        const SizedBox(
                          width: 15,
                        ),
                        Container(
                            padding: isAudio
                                ? EdgeInsets.all(0)
                                : EdgeInsets.all(13),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width / 2,
                            ),
                            decoration: BoxDecoration(
                                color: isMe ? meBubbleColor : Colors.grey[200],
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(15),
                                    topRight: Radius.circular(15),
                                    bottomLeft: Radius.circular(isMe ? 15 : 0),
                                    bottomRight:
                                        Radius.circular(isMe ? 0 : 15))),
                            child: isAudio
                                ? Expanded(
                                    child: WaveBubble(
                                      index: index,
                                      isSender: isMe,
                                      width:
                                          MediaQuery.of(context).size.width / 2,
                                      appDirectory: message.content,
                                    ),
                                  )
                                : SelectableText(message.content)),
                        if (!isMe && !isTyping)
                          IconButton(
                              icon: Icon(Icons.play_arrow),
                              color: Colors.grey[600],
                              onPressed: () async {
                                getPath();
                                // 각 메시지의 오디오 파일 경로를 사용해야 하나, 이 예제에서는 filePath가 고정입니다.
                                // 실제 애플리케이션에서는 message 객체 내의 고유한 파일 경로를 사용해야 합니다.
                                await audioPlayer
                                    .play(DeviceFileSource(filePath)); // 예시
                              }),
                      ]),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      mainAxisAlignment: isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (!isMe)
                          SizedBox(
                            width: 45,
                          ),
                        SizedBox(
                          width: 5,
                        ),
                        Text(
                          message.timestamp,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        )
                      ],
                    ),
                  )
                ],
              ));
        });
  }
}
