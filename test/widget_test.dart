// test/widget_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:airshare/models/peer.dart';

void main() {
  group('Peer Model Tests', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'test-uuid-1234',
        'name': 'Laptop-Alpha',
        'port': 53531,
        'deviceType': 'windows',
      };
      
      final senderIp = '192.168.1.50';
      final peer = Peer.fromJson(json, senderIp);

      expect(peer.id, 'test-uuid-1234');
      expect(peer.name, 'Laptop-Alpha');
      expect(peer.ipAddress, senderIp);
      expect(peer.port, 53531);
      expect(peer.deviceType, 'windows');
      expect(peer.lastSeen, isNotNull);
    });

    test('toJson returns correct map', () {
      final peer = Peer(
        id: 'test-uuid-5678',
        name: 'Phone-Beta',
        ipAddress: '192.168.1.100',
        port: 53531,
        deviceType: 'android',
        lastSeen: DateTime.now(),
      );

      final json = peer.toJson();

      expect(json['id'], 'test-uuid-5678');
      expect(json['name'], 'Phone-Beta');
      expect(json['port'], 53531);
      expect(json['deviceType'], 'android');
      expect(json['ipAddress'], '192.168.1.100'); 
    });
  });
}
