// lib/services/discovery_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/peer.dart';

class DiscoveryService {
  static const int udpPort = 53530;
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final int tcpPort;

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  final _peerController = StreamController<Peer>.broadcast();

  Stream<Peer> get peerStream => _peerController.stream;

  DiscoveryService({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.tcpPort,
  });

  Future<void> start() async {
    // 1. Bind to UDP port to listen for incoming broadcasts
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort);
      _socket!.broadcastEnabled = true;
      
      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            try {
              final rawString = utf8.decode(datagram.data);
              final json = jsonDecode(rawString) as Map<String, dynamic>;
              
              // Skip our own broadcasts
              if (json['id'] == deviceId) return;

              final peer = Peer.fromJson(json, datagram.address.address);
              _peerController.add(peer);
            } catch (e) {
              // Ignore malformed packets or conversion errors
            }
          }
        }
      });
      print("UDP Discovery listening on port $udpPort");
    } catch (e) {
      print("Error binding UDP socket: $e");
    }

    // 2. Start broadcasting our presence periodically (every 2 seconds)
    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) => _broadcastPresence());
    // Run once immediately
    _broadcastPresence();
  }

  Future<void> _broadcastPresence() async {
    if (_socket == null) return;
    
    try {
      final info = NetworkInfo();
      final localIp = await info.getWifiIP() ?? '0.0.0.0';
      
      final packet = {
        'id': deviceId,
        'name': deviceName,
        'ipAddress': localIp,
        'port': tcpPort,
        'deviceType': deviceType,
      };

      final data = utf8.encode(jsonEncode(packet));
      
      // Broadcast to subnet (255.255.255.255)
      _socket!.send(data, InternetAddress('255.255.255.255'), udpPort);
    } catch (e) {
      print("Error broadcasting presence: $e");
    }
  }

  void stop() {
    _broadcastTimer?.cancel();
    _socket?.close();
    _socket = null;
    print("UDP Discovery stopped.");
  }
}
