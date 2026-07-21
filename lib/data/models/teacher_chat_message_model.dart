import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherChatMessageModel {
  const TeacherChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    required this.isTeacher,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime sentAt;
  final bool isTeacher;

  factory TeacherChatMessageModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawDate = data['sentAt'];
    DateTime sentAt = DateTime.now();
    if (rawDate is Timestamp) {
      sentAt = rawDate.toDate();
    } else if (rawDate is String) {
      sentAt = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    return TeacherChatMessageModel(
      id: id,
      senderId: (data['senderId'] ?? '').toString(),
      senderName: (data['senderName'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      sentAt: sentAt,
      isTeacher: data['isTeacher'] == true,
    );
  }

  factory TeacherChatMessageModel.fromJson(Map<String, dynamic> data) {
    return TeacherChatMessageModel(
      id: (data['id'] ?? '').toString(),
      senderId: (data['senderId'] ?? '').toString(),
      senderName: (data['senderName'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      sentAt: DateTime.tryParse((data['sentAt'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
      isTeacher: data['isTeacher'] == true,
    );
  }
}
