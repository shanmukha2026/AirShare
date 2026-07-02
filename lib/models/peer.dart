// lib/models/peer.dart

class Peer {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final String deviceType; // 'android', 'windows', 'macos', 'ios', 'unknown'
  final DateTime lastSeen;

  Peer({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.deviceType,
    required this.lastSeen,
  });

  // Convert peer info to JSON for UDP broadcasting
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ipAddress': ipAddress,
      'port': port,
      'deviceType': deviceType,
    };
  }

  // Parse peer info from received UDP broadcast packets
  factory Peer.fromJson(Map<String, dynamic> json, String senderIp) {
    return Peer(
      id: json['id'] as String,
      name: json['name'] as String,
      ipAddress: senderIp, // Use the actual network sender IP
      port: json['port'] as int,
      deviceType: json['deviceType'] as String? ?? 'unknown',
      lastSeen: DateTime.now(),
    );
  }

  // Helper copyWith method
  Peer copyWith({
    String? id,
    String? name,
    String? ipAddress,
    int? port,
    String? deviceType,
    DateTime? lastSeen,
  }) {
    return Peer(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      deviceType: deviceType ?? this.deviceType,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Peer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
