import 'package:flutter_test/flutter_test.dart';
import 'package:ontime/domain/models/chat_message.dart';

void main() {
  final baseMap = <String, dynamic>{
    'id': 'msg-1',
    'sender_id': 'user-a',
    'receiver_id': 'user-b',
    'content': 'Oi!',
    'type': 'text',
    'metadata': null,
    'read_at': null,
    'created_at': '2026-01-01T12:00:00.000Z',
  };

  group('ChatMessage.fromMap', () {
    test('parses all basic fields', () {
      final msg = ChatMessage.fromMap(baseMap);
      expect(msg.id, 'msg-1');
      expect(msg.senderId, 'user-a');
      expect(msg.receiverId, 'user-b');
      expect(msg.content, 'Oi!');
      expect(msg.type, ChatMessageType.text);
      expect(msg.metadata, isNull);
      expect(msg.readAt, isNull);
    });

    test('parses created_at as local DateTime', () {
      final msg = ChatMessage.fromMap(baseMap);
      expect(msg.createdAt, isA<DateTime>());
    });

    test('parses poke type correctly', () {
      final msg = ChatMessage.fromMap({...baseMap, 'type': 'poke'});
      expect(msg.type, ChatMessageType.poke);
    });

    test('parses reaction type correctly', () {
      final msg = ChatMessage.fromMap({
        ...baseMap,
        'type': 'reaction',
        'metadata': {'emoji': '🔥'},
      });
      expect(msg.type, ChatMessageType.reaction);
      expect(msg.metadata, {'emoji': '🔥'});
    });

    test('unknown type falls back to text', () {
      final msg = ChatMessage.fromMap({...baseMap, 'type': 'unknown_type'});
      expect(msg.type, ChatMessageType.text);
    });

    test('missing type field falls back to text', () {
      final map = Map<String, dynamic>.from(baseMap)..remove('type');
      final msg = ChatMessage.fromMap(map);
      expect(msg.type, ChatMessageType.text);
    });

    test('parses read_at when present', () {
      final msg = ChatMessage.fromMap({
        ...baseMap,
        'read_at': '2026-01-01T13:00:00.000Z',
      });
      expect(msg.readAt, isNotNull);
    });

    test('metadata is null when absent', () {
      final msg = ChatMessage.fromMap({...baseMap, 'metadata': null});
      expect(msg.metadata, isNull);
    });
  });

  group('isRead', () {
    test('false when read_at is null', () {
      final msg = ChatMessage.fromMap(baseMap);
      expect(msg.isRead, isFalse);
    });

    test('true when read_at is set', () {
      final msg = ChatMessage.fromMap({
        ...baseMap,
        'read_at': '2026-01-01T13:00:00.000Z',
      });
      expect(msg.isRead, isTrue);
    });
  });

  group('previewText', () {
    test('text message returns content', () {
      final msg = ChatMessage.fromMap(baseMap);
      expect(msg.previewText, 'Oi!');
    });

    test('poke returns cutucada string', () {
      final msg = ChatMessage.fromMap({...baseMap, 'type': 'poke'});
      expect(msg.previewText, '👋 Cutucada!');
    });

    test('reaction returns emoji from metadata', () {
      final msg = ChatMessage.fromMap({
        ...baseMap,
        'type': 'reaction',
        'metadata': {'emoji': '🔥'},
      });
      expect(msg.previewText, contains('🔥'));
    });

    test('reaction without metadata emoji falls back to ❤️', () {
      final msg = ChatMessage.fromMap({
        ...baseMap,
        'type': 'reaction',
        'metadata': null,
      });
      expect(msg.previewText, contains('❤️'));
    });
  });
}
