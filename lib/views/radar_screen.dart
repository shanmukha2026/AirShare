// lib/views/radar_screen.dart

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/peer.dart';
import '../models/transfer.dart';
import '../providers/peer_provider.dart';
import '../providers/transfer_provider.dart';
import '../providers/theme_provider.dart';
import '../services/sound_service.dart';
import 'widgets/radar_painter.dart';

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Animation for the rotating radar scan line
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Animation for expanding radar rings
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Start discovery and start the server
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(peerProvider.notifier).startDiscovery();
      ref.read(transferProvider.notifier).startServer();
    });

    // Listen for completed transfers to play ding sound
    _listenForCompletedTransfers();
  }

  void _listenForCompletedTransfers() {
    // Will be called via ref.listen in build
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Handle incoming file alert dialog
  void _listenForAlerts() {
    ref.listen<FileTransfer?>(alertStateProvider, (previous, next) {
      if (next != null) {
        SoundService.playWhoosh(); // play sound when file request arrives
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E2830),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.cyan, width: 1),
            ),
            title: Row(
              children: const [
                Icon(Icons.downloading, color: Colors.cyan),
                SizedBox(width: 8),
                Text(
                  "Incoming File",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${next.peerName} wants to send a file to you:",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Text(
                  next.fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _formatBytes(next.fileSize),
                  style: const TextStyle(color: Colors.cyan, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ref.read(transferProvider.notifier).rejectTransfer(next.id);
                  ref.read(alertStateProvider.notifier).state = null;
                  Navigator.of(context).pop();
                },
                child: const Text("REJECT", style: TextStyle(color: Colors.redAccent)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  ref.read(transferProvider.notifier).acceptTransfer(next.id);
                  ref.read(alertStateProvider.notifier).state = null;
                  Navigator.of(context).pop();
                },
                child: const Text("ACCEPT", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    });
  }

  // File selection and sending trigger
  Future<void> _selectAndSendFile(Peer peer) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final name = result.files.single.name;
      final file = File(path);

      SoundService.playWhoosh(); // 🔊 whoosh when sending starts
      await ref.read(transferProvider.notifier).sendFile(peer.id, peer.ipAddress, name, file);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for completed transfers → play ding
    ref.listen<Map<String, FileTransfer>>(transferProvider, (prev, next) {
      if (prev == null) return;
      for (final id in next.keys) {
        final newT = next[id];
        final oldT = prev[id];
        if (newT?.status == TransferStatus.completed &&
            oldT?.status != TransferStatus.completed) {
          SoundService.playDing();
        }
      }
    });

    _listenForAlerts();

    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final peers = ref.watch(peerProvider);
    final transfers = ref.watch(transferProvider);
    final myDeviceName = ref.read(peerProvider.notifier).deviceName;
    final myDeviceType = ref.read(peerProvider.notifier).deviceType;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F171E) : const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(myDeviceName, myDeviceType, peers.length, isDark),

            // Radar Workspace
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = min(constraints.maxWidth, constraints.maxHeight) * 0.85;
                  final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
                  final maxRadius = size / 2;

                  return Stack(
                    children: [
                      // Animated Radar BG
                      Center(
                        child: AnimatedBuilder(
                          animation: Listenable.merge(
                              [_radarController, _pulseController]),
                          builder: (context, child) {
                            return CustomPaint(
                              size: Size(size, size),
                              painter: RadarPainter(
                                angle: _radarController.value * 2 * pi,
                                pulseValue: _pulseController.value,
                              ),
                            );
                          },
                        ),
                      ),

                      // Center Device Icon
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2830),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.cyan, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyan.withOpacity(0.3),
                                blurRadius: 16,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: Icon(
                            _getDeviceIcon(myDeviceType),
                            color: Colors.cyan,
                            size: 28,
                          ),
                        ),
                      ),

                      // Discovered Peer Nodes
                      ...peers.map((peer) {
                        // Deterministic location based on peer ID hash
                        final angle = peer.id.hashCode % (2 * pi);
                        final distanceFraction =
                            0.4 + (peer.id.hashCode % 10) / 25.0; // between 0.4 and 0.8
                        final radius = maxRadius * distanceFraction;

                        final x = center.dx + radius * cos(angle) - 30; // 30 is half of peer node width (60)
                        final y = center.dy + radius * sin(angle) - 35;

                        return Positioned(
                          left: x,
                          top: y,
                          child: _buildPeerNode(peer),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),

            // Active Transfers Panel
            _buildTransfersPanel(transfers.values.toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String name, String type, int peerCount, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0xFF16202A),
        border: Border(bottom: BorderSide(color: Color(0xFF26323E), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Title + subtitle + device name
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    "AirShare",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.cyan.withOpacity(0.35)),
                    ),
                    child: const Text(
                      "v1.2.0",
                      style: TextStyle(
                        color: Colors.cyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                "Built by Pardhu",
                style: TextStyle(
                  color: Colors.cyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(_getDeviceIcon(type), color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          // Right side: Theme toggle + peer count
          Row(
            children: [
              GestureDetector(
                onTap: () => ref.read(themeProvider.notifier).toggle(),
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F171E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                  ),
                  child: Icon(
                    isDark ? Icons.light_mode : Icons.dark_mode,
                    color: Colors.cyan,
                    size: 18,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F171E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: peerCount > 0 ? Colors.green : Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      peerCount > 0 ? "$peerCount Peers Active" : "Scanning...",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildPeerNode(Peer peer) {
    return GestureDetector(
      onTap: () => _selectAndSendFile(peer),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2830),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.cyan.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ],
            ),
            child: Icon(
              _getDeviceIcon(peer.deviceType),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              peer.name.split(' (')[0], // Shorten name
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            peer.ipAddress,
            style: const TextStyle(color: Colors.cyan, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildTransfersPanel(List<FileTransfer> transfersList) {
    // Show only the 3 most recent transfers to keep UI clean
    final activeTransfers = transfersList
        .where((t) => t.status == TransferStatus.transferring || t.status == TransferStatus.pending)
        .toList();
    final historicTransfers = transfersList
        .where((t) => t.status != TransferStatus.transferring && t.status != TransferStatus.pending)
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id)); // show newest first

    final displayList = [...activeTransfers, ...historicTransfers].take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0xFF16202A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Transfers",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (transfersList.isNotEmpty)
                Text(
                  "${transfersList.length} Total",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (displayList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  "No active transfers. Tap a peer on the radar to send a file.",
                  style: TextStyle(color: Colors.white30, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...displayList.map((transfer) => _buildTransferItem(transfer)),
        ],
      ),
    );
  }

  Widget _buildTransferItem(FileTransfer transfer) {
    final progressVal = transfer.progress;
    final isDone = transfer.status == TransferStatus.completed;
    final isFailed = transfer.status == TransferStatus.failed;
    final isRejected = transfer.status == TransferStatus.rejected;
    final isPending = transfer.status == TransferStatus.pending;

    Color statusColor = Colors.cyan;
    if (isDone) statusColor = Colors.green;
    if (isFailed || isRejected) statusColor = Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2830),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: transfer.status == TransferStatus.transferring
                ? Colors.cyan.withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  transfer.isDownload ? Icons.arrow_downward : Icons.arrow_upward,
                  color: statusColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transfer.fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        transfer.isDownload
                            ? "From: ${transfer.peerName}"
                            : "To: ${transfer.peerName}",
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isDone
                          ? "Completed"
                          : isFailed
                              ? "Failed"
                              : isRejected
                                  ? "Rejected"
                                  : isPending
                                      ? "Connecting..."
                                      : "${(progressVal * 100).toStringAsFixed(0)}%",
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (transfer.status == TransferStatus.transferring)
                      Text(
                        "${transfer.speed.toStringAsFixed(1)} MB/s",
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                  ],
                ),
              ],
            ),
            if (transfer.status == TransferStatus.transferring) ...[
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: progressVal),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, animValue, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        // Background
                        Container(
                          height: 6,
                          color: const Color(0xFF0F171E),
                        ),
                        // Animated fill
                        FractionallySizedBox(
                          widthFactor: animValue.clamp(0.0, 1.0),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.cyan, Colors.cyanAccent],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyan.withOpacity(0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            if (isFailed && transfer.errorMessage != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  transfer.errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String type) {
    switch (type) {
      case 'android':
        return Icons.phone_android;
      case 'windows':
        return Icons.laptop_windows;
      case 'macos':
      case 'ios':
        return Icons.phone_iphone;
      default:
        return Icons.devices;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}";
  }
}
