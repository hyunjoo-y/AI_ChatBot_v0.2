import 'package:chatbot/models/chatroom_model.dart';
import 'package:chatbot/models/message_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._();
  static Database? _database;

  DBHelper._();

  factory DBHelper() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'chat.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chatrooms (
        id TEXT PRIMARY KEY,
        name TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chatroom_id TEXT,
        sender INTEGER,
        type TEXT,
        content TEXT,
        timestamp TEXT,
        FOREIGN KEY (chatroom_id) REFERENCES chatrooms(id)
      )
    ''');
  }

  Future<void> _onOpen(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chatrooms (
        id TEXT PRIMARY KEY,
        name TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chatroom_id TEXT,
        sender INTEGER,
        type TEXT,
        content TEXT,
        timestamp TEXT,
        FOREIGN KEY (chatroom_id) REFERENCES chatrooms(id)
      )
    ''');
  }

  Future<int> createChatroom(ChatRoom chatroom) async {
    final db = await database;
    return await db.insert('chatrooms', chatroom.toMap());
  }

  Future<void> insertMessage(String chatroomId, Message message) async {
    final db = await database;
    await db.insert('messages', {
      'chatroom_id': chatroomId,
      ...message.toMap(),
    });
  }

  Future<void> deleteChatroom(String id) async {
    final db = await database;
    await db.delete('chatrooms', where: 'id = ?', whereArgs: [id]);
    await db.delete('messages', where: 'chatroom_id = ?', whereArgs: [id]);
  }

  Future<void> deleteMessage(Message message, String chatroomId) async {
    final db = await database;
    int count = await db.delete(
      'messages',
      where: 'content = ? AND timestamp = ? AND chatroom_id = ?',
      whereArgs: [message.content, message.timestamp, chatroomId],
    );
    print(
        'Deleted $count message(s) with message ${message.content} from chatroom $chatroomId');
  }

  Future<List<Message>> fetchMessages(String chatroomId) async {
    final db = await database;
    final maps = await db.query('messages',
        where: 'chatroom_id = ?', whereArgs: [chatroomId], orderBy: 'id DESC');

    return List.generate(maps.length, (i) {
      return Message.fromMap(maps[i]);
    });
  }

  Future<List<ChatRoom>> fetchChatrooms() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT chatrooms.*, MAX(messages.timestamp) as last_message_time
      FROM chatrooms
      LEFT JOIN messages ON chatrooms.id = messages.chatroom_id
      GROUP BY chatrooms.id 
      ORDER BY chatrooms.id  DESC
    ''');
    // ORDER BY last_message_time DESC
    return List.generate(maps.length, (i) {
      return ChatRoom.fromMap(maps[i]);
    });
  }

  Future<ChatRoom?> getChatroomByName(String name) async {
    final db = await database;
    final results =
        await db.query('chatrooms', where: 'name = ?', whereArgs: [name]);
    if (results.isNotEmpty) {
      return ChatRoom.fromMap(results.first);
    }
    return null;
  }
}
