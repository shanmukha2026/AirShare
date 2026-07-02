// lib/providers/peer_provider.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/peer.dart';
import '../services/discovery_service.dart';

// TCP Port used for transferring files
const int tcpTransferPort = 53531;

class PeerListNotifier extends StateNotifier<List<Peer>> {
  final Ref ref;
  late final String _deviceId;
  late final String _deviceName;
  late final String _deviceType;
  
  DiscoveryService? _discoveryService;
  Timer? _pruningTimer;
  StreamSubscription? _streamSubscription;

  PeerListNotifier(this.ref) : super([]) {
    _initDeviceDetails();
  }

  void _initDeviceDetails() {
    _deviceId = const Uuid().v4();
    
    // Get friendly name
    String hostname = Platform.localHostname;
    if (hostname.isEmpty || hostname == 'localhost') {
      hostname = Platform.isAndroid ? 'Android Device' : 'PC';
    }
    
    final shortId = _deviceId.substring(0, 4).toUpperCase();
    _deviceName = "$hostname ($shortId)";

    if (Platform.isAndroid) {
      _deviceType = 'android';
    } else if (Platform.isWindows) {
      _deviceType = 'windows';
    } else if (Platform.isMacOS) {
      _deviceType = 'macos';
    } else if (Platform.isIOS) {
      _deviceType = 'ios';
    } else {
      _deviceType = 'unknown';
    }
  }

  String get deviceName => _deviceName;
  String get deviceId => _deviceId;
  String get deviceType => _deviceType;

  void startDiscovery() {
    if (_discoveryService != null) return;

    _discoveryService = DiscoveryService(
      deviceId: _deviceId,
      deviceName: _deviceName,
      deviceType: _deviceType,
      tcpPort: tcpTransferPort,
    );

    // Listen for discovered peers
    _streamSubscription = _discoveryService!.peerStream.listen((Peer peer) {
      _addOrUpdatePeer(peer);
    });

    _discoveryService!.start();

    // Prune dead peers every 4 seconds
    _pruningTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pruneInactivePeers());
  }

  void _addOrUpdatePeer(Peer peer) {
    final index = state.indexWhere((p) => p.id == peer.id);
    if (index == -1) {
      // New peer discovered!
      state = [...state, peer];
    } else {
      // Existing peer, update its details and timestamp
      final updatedPeers = List<Peer>.from(state);
      updatedPeers[index] = peer.copyWith(lastSeen: DateTime.now());
      state = updatedPeers;
    }
  }

  void _pruneInactivePeers() {
    final now = DateTime.now();
    // Remove peers not heard from in 8 seconds
    final activePeers = state.where((peer) {
      return now.difference(peer.lastSeen).inSeconds < 8;
    }).toList();

    if (activePeers.length != state.length) {
      state = activePeers;
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _pruningTimer?.cancel();
    _discoveryService?.stop();
    super.dispose();
  }
}

// Provider exposing the list of discovered peers
final peerProvider = StateNotifierProvider<PeerListNotifier, List<Peer>>((ref) {
  return PeerListNotifier(ref);
});
