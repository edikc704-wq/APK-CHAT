class ChatMessage {
  final String key;
  final String sender;
  final String type; // text, image, video, file
  final String text;
  final String time;
  final int timestamp;
  final bool isBot;
  final bool isWounNotif;
  final bool deleted;
  final String? imageData;
  final String? videoData;
  final String? fileData;
  final String? fileName;
  final String? fileSize;

  ChatMessage({
    required this.key,
    required this.sender,
    required this.type,
    required this.text,
    required this.time,
    required this.timestamp,
    this.isBot = false,
    this.isWounNotif = false,
    this.deleted = false,
    this.imageData,
    this.videoData,
    this.fileData,
    this.fileName,
    this.fileSize,
  });

  factory ChatMessage.fromMap(String key, Map data) {
    return ChatMessage(
      key: key,
      sender: data['sender']?.toString() ?? '',
      type: data['type']?.toString() ?? 'text',
      text: data['text']?.toString() ?? '',
      time: data['time']?.toString() ?? '',
      timestamp: (data['timestamp'] is int) ? data['timestamp'] : int.tryParse('${data['timestamp']}') ?? 0,
      isBot: data['isBot'] == true,
      isWounNotif: data['isWounNotif'] == true,
      deleted: data['deleted'] == true,
      imageData: data['imageData']?.toString(),
      videoData: data['videoData']?.toString(),
      fileData: data['fileData']?.toString(),
      fileName: data['fileName']?.toString(),
      fileSize: data['fileSize']?.toString(),
    );
  }
}

class ChatSummary {
  final String target;
  final String lastMsg;
  final int lastTime;
  ChatSummary({required this.target, required this.lastMsg, required this.lastTime});
}
