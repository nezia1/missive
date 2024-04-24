import 'package:hive/hive.dart';
part 'plain_text_message.g.dart'; // generated by Hive

@HiveType(typeId: 0)
class PlainTextMessage {
  @HiveField(0)
  final String content;
  @HiveField(1)
  final bool own;
  @HiveField(2)
  final String? receiver;
  @HiveField(3)
  final DateTime? sentAt;

  PlainTextMessage(
      {required this.content, required this.own, this.receiver, this.sentAt});
}
