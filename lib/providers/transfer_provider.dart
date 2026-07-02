// lib/providers/transfer_provider.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/transfer.dart';
import '../services/transfer_service.dart';
import 'peer_provider.dart';

// State representing the active list of transfers
class TransferHistoryNotifier extends StateNotifier<Map<String, FileTransfer>> {
  final Ref ref;
  final TransferService _transferService = TransferService();
  
  // Keep track of active sockets for incoming requests before they are accepted/rejected
  final Map<String, Socket> _pendingSockets = {};

  // Store the active incoming transfer request, if any
  FileTransfer? _activeIncomingRequest;
  final Function(FileTransfer request) _onIncomingRequestAlert;

  TransferHistoryNotifier(this.ref, this._onIncomingRequestAlert) : super({});

  FileTransfer? get activeIncomingRequest => _activeIncomingRequest;

  // Initialize the TCP Server to listen for files
  void startServer() {
    _transferService.startServer(
      port: tcpTransferPort,
      onRequestReceived: (transferId, peerName, fileName, fileSize, socket) {
        _pendingSockets[transferId] = socket;
        
        final newTransfer = FileTransfer(
          id: transferId,
          fileName: fileName,
          fileSize: fileSize,
          bytesTransferred: 0,
          speed: 0.0,
          isDownload: true,
          status: TransferStatus.pending,
          peerName: peerName,
        );

        // Add to history and set as active alert
        state = {...state, transferId: newTransfer};
        _activeIncomingRequest = newTransfer;
        
        // Notify UI to pop up dialog
        _onIncomingRequestAlert(newTransfer);
      },
    );
  }

  // User accepts the file transfer
  Future<void> acceptTransfer(String transferId) async {
    final socket = _pendingSockets.remove(transferId);
    final transfer = state[transferId];
    if (socket == null || transfer == null) return;

    _activeIncomingRequest = null; // Clear active alert alert

    // Update status to transferring
    state = {
      ...state,
      transferId: transfer.copyWith(status: TransferStatus.transferring),
    };

    final savePath = await _getSavePath(transfer.fileName);

    // Start receiving stream
    _transferService.receiveFile(
      socket: socket,
      savePath: savePath,
      expectedSize: transfer.fileSize,
      onProgress: (bytes, speed) {
        state = {
          ...state,
          transferId: state[transferId]!.copyWith(
            bytesTransferred: bytes,
            speed: speed,
          ),
        };
      },
      onComplete: () {
        state = {
          ...state,
          transferId: state[transferId]!.copyWith(
            status: TransferStatus.completed,
            speed: 0.0,
          ),
        };
      },
      onError: (err) {
        state = {
          ...state,
          transferId: state[transferId]!.copyWith(
            status: TransferStatus.failed,
            errorMessage: err,
            speed: 0.0,
          ),
        };
      },
    );
  }

  // User rejects the file transfer
  void rejectTransfer(String transferId) {
    final socket = _pendingSockets.remove(transferId);
    final transfer = state[transferId];
    if (socket == null || transfer == null) return;

    _activeIncomingRequest = null; // Clear active alert

    _transferService.rejectRequest(socket);
    
    state = {
      ...state,
      transferId: transfer.copyWith(status: TransferStatus.rejected),
    };
  }

  // Initiate file sending to a peer
  Future<void> sendFile(String peerId, String peerIp, String fileName, File file) async {
    final transferId = const Uuid().v4();
    final fileSize = await file.length();
    final senderName = ref.read(peerProvider.notifier).deviceName;

    final newTransfer = FileTransfer(
      id: transferId,
      fileName: fileName,
      fileSize: fileSize,
      bytesTransferred: 0,
      speed: 0.0,
      isDownload: false,
      status: TransferStatus.pending,
      peerName: senderName,
    );

    state = {...state, transferId: newTransfer};

    _transferService.sendFile(
      ipAddress: peerIp,
      port: tcpTransferPort,
      transferId: transferId,
      senderName: senderName,
      file: file,
      onProgress: (bytes, speed) {
        state = {
          ...state,
          transferId: state[transferId]!.copyWith(
            bytesTransferred: bytes,
            speed: speed,
            status: TransferStatus.transferring,
          ),
        };
      },
      onComplete: () {
        state = {
          ...state,
          transferId: state[transferId]!.copyWith(
            status: TransferStatus.completed,
            speed: 0.0,
          ),
        };
      },
      onError: (err) {
        state = {
          ...state,
          transferId: state[transferId]!.copyWith(
            status: TransferStatus.failed,
            errorMessage: err,
            speed: 0.0,
          ),
        };
      },
      onRejected: () {
        state = {
          ...state,
          transferId: state[transferId]!.copyWith(
            status: TransferStatus.rejected,
            speed: 0.0,
          ),
        };
      },
    );
  }

  Future<String> _getSavePath(String fileName) async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        dir = await getExternalStorageDirectory();
      }
    } else {
      dir = await getDownloadsDirectory();
      dir ??= await getApplicationDocumentsDirectory();
    }
    
    // Ensure directory exists
    if (dir != null && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    String path = "${dir!.path}${Platform.pathSeparator}$fileName";
    
    // Deconflict filename if file already exists
    int counter = 1;
    final file = File(path);
    if (await file.exists()) {
      final nameParts = fileName.split('.');
      final ext = nameParts.length > 1 ? nameParts.last : '';
      final base = nameParts.length > 1 
          ? nameParts.sublist(0, nameParts.length - 1).join('.') 
          : fileName;
      
      while (await File("${dir.path}${Platform.pathSeparator}${base}_$counter.$ext").exists()) {
        counter++;
      }
      path = "${dir.path}${Platform.pathSeparator}${base}_$counter.$ext";
    }
    
    return path;
  }

  @override
  void dispose() {
    _transferService.stopServer();
    for (var socket in _pendingSockets.values) {
      socket.close();
    }
    super.dispose();
  }
}

// Global hook to notify the UI when a transfer request alert is triggered
final alertStateProvider = StateProvider<FileTransfer?>((ref) => null);

// Riverpod Provider exposing transfer history and methods
final transferProvider = StateNotifierProvider<TransferHistoryNotifier, Map<String, FileTransfer>>((ref) {
  return TransferHistoryNotifier(ref, (request) {
    ref.read(alertStateProvider.notifier).state = request;
  });
});
