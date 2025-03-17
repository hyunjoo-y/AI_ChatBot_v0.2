import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:chatbot/components/backgroud.dart';
import 'package:chatbot/models/database_service.dart';
import 'package:chatbot/models/message_model.dart';
import 'package:chatbot/models/wave_model.dart';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

class Conversation extends StatefulWidget {
  final List<Message> msg;
  final bool isTyping;
  final VoidCallback pauseTyping;
  final String chatRoom_id;

  Conversation({
    required this.msg,
    required this.isTyping,
    required this.pauseTyping,
    required this.chatRoom_id,
  });

  @override
  State<Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<Conversation> {
  late String filePath;
  bool isPlaying = true;
  bool isButtonVisible = true;

  DBHelper _dbHelper = DBHelper();

  @override
  void initState() {
    super.initState();
    getPath();
  }

  void getPath() async {
    var dir = await path_provider.getApplicationDocumentsDirectory();
    filePath = "${dir.path}/recording.wav";
  }

  void _onPlayPausePressed() {
    if (widget.isTyping && isPlaying) {
      widget.pauseTyping();
      setState(() {
        isPlaying = false;
      });
    }
  }

  Future<void> _saveImage(String base64Image) async {
    try {
      Uint8List bytes = base64Decode(base64Image);
      print("Decoded bytes: ${bytes.length}");
      final result = await ImageGallerySaver.saveImage(bytes);
      print("Save result: $result");
      if (result['isSuccess']) {
        Fluttertoast.showToast(msg: "Image saved to gallery");
      } else {
        Fluttertoast.showToast(msg: "Failed to save image.");
      }
    } catch (e) {
      print("Error: $e");
      Fluttertoast.showToast(msg: "Error saving image: $e");
    }
  }

  void _showSaveDialog(String base64Image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Save Image"),
          content: Text("Do you want to save this image to your gallery?"),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Save"),
              onPressed: () async {
                Navigator.of(context).pop();
                await _saveImage(base64Image);
              },
            ),
          ],
        );
      },
    );
  }

  void _showImageDialog(List<String> images, int initialPage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8, // 다이얼로그 너비 조정
            height: MediaQuery.of(context).size.height * 0.6, // 다이얼로그 높이 조정
            child: ImageDialog(
              images: images,
              initialPage: initialPage,
              onLongPress: (base64Image) => _showSaveDialog(base64Image),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final audioPlayer = AudioPlayer();

    return ListView.builder(
      key: ValueKey(widget.msg), // 리스트 전체에 대한 고유 키 추가
      reverse: true,
      itemCount: widget.msg.length,
      itemBuilder: (context, int index) {
        final message = widget.msg[index];

        bool isMe = message.sender == true;
        bool isAudio = message.type == 'audio';
        bool isText = message.type == 'text'; // 예시로 추가된 텍스트 메시지 확인
        bool isImage = message.type == 'image';
        bool isLoading = message.type == 'loading';
        bool isTyping = message.content == 'Typing...';

        return Dismissible(
          key: Key(message.content.toString()), // 메시지의 고유 키 사용
          direction: DismissDirection.endToStart, // 오른쪽에서 왼쪽으로 스와이프할 때만 삭제
          onDismissed: (direction) async {
            await _dbHelper.deleteMessage(message, widget.chatRoom_id);
            setState(() {
              widget.msg.removeAt(index);
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Message deleted'),
                duration: Duration(milliseconds: 50),
              ),
            );
          },
          confirmDismiss: (direction) async {
            // Confirm before dismissing
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("Delete Confirmation"),
                  content:
                      Text("Are you sure you want to delete this message?"),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text("Delete"),
                    ),
                  ],
                );
              },
            );
          },
          background: Container(
            color: Color.fromARGB(255, 160, 157, 159),
            alignment: Alignment.centerRight,
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.delete, color: Colors.white),
                SizedBox(width: 20),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          child: Container(
            margin: EdgeInsets.only(top: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment:
                      isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMe)
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 15,
                        backgroundImage: AssetImage('assets/aieev.jpeg'),
                      ),
                    const SizedBox(width: 15),
                    Container(
                      padding: isAudio ? EdgeInsets.all(0) : EdgeInsets.all(13),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width / 2,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? list1 : Colors.grey[200],
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(15),
                          topRight: Radius.circular(15),
                          bottomLeft: Radius.circular(isMe ? 15 : 0),
                          bottomRight: Radius.circular(isMe ? 0 : 15),
                        ),
                      ),
                      child: isAudio
                          ? Expanded(
                              child: WaveBubble(
                                index: index,
                                isSender: isMe,
                                width: MediaQuery.of(context).size.width / 2,
                                appDirectory: message.content,
                              ),
                            )
                          : isImage
                              ? Column(
                                  children: [
                                    Container(
                                      height:
                                          MediaQuery.of(context).size.width *
                                              0.5, // 동적 높이 설정
                                      child: ImageCarousel(
                                        message: message,
                                        onImageTap: (images, pageIndex) =>
                                            _showImageDialog(images, pageIndex),
                                      ),
                                    ),
                                  ],
                                )
                              : SelectableText(message.content),
                    ),
                    if ((!isMe && index == 0 && widget.isTyping) &&
                        (isText || isLoading))
                      IconButton(
                        icon: Icon(Icons.pause),
                        color: Color.fromARGB(255, 185, 182, 182),
                        onPressed: widget.pauseTyping,
                      ),
                    
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                    mainAxisAlignment:
                        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (!isMe) SizedBox(width: 45),
                      SizedBox(width: 5),
                      Text(
                        message.timestamp,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ImageCarousel extends StatefulWidget {
  final Message message;
  final void Function(List<String> images, int pageIndex) onImageTap;

  ImageCarousel({required this.message, required this.onImageTap});

  @override
  _ImageCarouselState createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  Widget build(BuildContext context) {
    List<String> images = widget.message.content.split(',');

    return Column(
      children: [
        Flexible(
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, pageIndex) {
              final base64Image = images[pageIndex];
              Uint8List bytes = base64Decode(base64Image);

              return GestureDetector(
                onTap: () => widget.onImageTap(images, pageIndex),
                onLongPress: () => _showSaveDialog(base64Image),
                child: Image.memory(
                  bytes,
                  gaplessPlayback: true, // 깜빡임 방지
                  key: ValueKey<String>(base64Image), // 캐시 키로 사용할 값 설정
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'Page ${_currentPage + 1} of ${images.length}',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  void _showSaveDialog(String base64Image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Save Image"),
          content: Text("Do you want to save this image to your gallery?"),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Save"),
              onPressed: () async {
                Navigator.of(context).pop();
                await _saveImage(base64Image);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveImage(String base64Image) async {
    try {
      Uint8List bytes = base64Decode(base64Image);
      print("Decoded bytes: ${bytes.length}");
      final result = await ImageGallerySaver.saveImage(bytes);
      print("Save result: $result");
      if (result['isSuccess']) {
        Fluttertoast.showToast(msg: "Image saved to gallery.");
      } else {
        Fluttertoast.showToast(msg: "Failed to save image.");
      }
    } catch (e) {
      print("Error: $e");
      Fluttertoast.showToast(msg: "Error saving image: $e");
    }
  }
}

class ImageDialog extends StatefulWidget {
  final List<String> images;
  final int initialPage;
  final void Function(String base64Image) onLongPress;

  ImageDialog({
    required this.images,
    required this.initialPage,
    required this.onLongPress,
  });

  @override
  _ImageDialogState createState() => _ImageDialogState();
}

class _ImageDialogState extends State<ImageDialog> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage);
    _currentPage = widget.initialPage;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Flexible(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, pageIndex) {
              final base64Image = widget.images[pageIndex];
              return GestureDetector(
                onLongPress: () => widget.onLongPress(base64Image),
                child: Image.memory(
                  base64Decode(base64Image),
                  gaplessPlayback: true, // 깜빡임 방지
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'Page ${_currentPage + 1} of ${widget.images.length}',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
