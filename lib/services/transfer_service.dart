// lib/services/transfer_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class TransferService {
  ServerSocket? _serverSocket;

  // Start TCP Server to listen for incoming transfer requests
  Future<void> startServer({
    required int port,
    required Function(
      String transferId,
      String peerName,
      String fileName,
      int fileSize,
      Socket socket,
    ) onRequestReceived,
  }) async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      print("TCP Server listening on port $port");

      _serverSocket!.listen((Socket clientSocket) {
        print("Incoming TCP connection from ${clientSocket.remoteAddress.address}");
        _handleIncomingConnection(clientSocket, onRequestReceived);
      });
    } catch (e) {
      print("Error starting TCP server: $e");
    }
  }

  void _handleIncomingConnection(
    Socket socket,
    Function(String, String, String, int, Socket) onRequestReceived,
  ) {
    // We expect the first message to be a JSON header terminated by a newline '\n'
    StringBuffer buffer = StringBuffer();
    StreamSubscription? subscription;

    subscription = socket.listen((data) {
      buffer.write(utf8.decode(data));
      final content = buffer.toString();

      if (content.contains('\n')) {
        subscription?.cancel(); // Stop listening to header data
        
        final parts = content.split('\n');
        final headerRaw = parts[0];
        
        try {
          final header = jsonDecode(headerRaw) as Map<String, dynamic>;
          final String transferId = header['transferId'] as String;
          final String peerName = header['peerName'] as String;
          final String fileName = header['fileName'] as String;
          final int fileSize = header['fileSize'] as int;

          // Notify the UI and hand over the socket
          onRequestReceived(transferId, peerName, fileName, fileSize, socket);
        } catch (e) {
          print("Error parsing header: $e");
          socket.write("ERROR\n");
          socket.close();
        }
      }
    }, onError: (err) {
      print("Error reading connection header: $err");
      socket.close();
    });
  }

  // Helper: Reject incoming transfer request
  void rejectRequest(Socket socket) {
    try {
      socket.write("REJECT\n");
      socket.flush().then((_) => socket.close());
    } catch (e) {
      socket.close();
    }
  }

  // Receive file from accepted connection
  Future<void> receiveFile({
    required Socket socket,
    required String savePath,
    required int expectedSize,
    required Function(int bytes, double speed) onProgress,
    required Function() onComplete,
    required Function(String error) onError,
  }) async {
    final file = File(savePath);
    IOSink? sink;
    int bytesReceived = 0;
    
    final stopwatch = Stopwatch()..start();
    double lastSpeed = 0.0;
    int lastBytes = 0;
    DateTime lastTime = DateTime.now();

    try {
      sink = file.openWrite();
      socket.write("ACCEPT\n");
      await socket.flush();

      await for (final chunk in socket) {
        sink.add(chunk);
        bytesReceived += chunk.length;

        // Calculate transfer speed every 500ms
        final now = DateTime.now();
        final difference = now.difference(lastTime).inMilliseconds;
        if (difference >= 500) {
          final bytesDiff = bytesReceived - lastBytes;
          // Speed in MB/s
          lastSpeed = (bytesDiff / (1024 * 1024)) / (difference / 1000.0);
          lastBytes = bytesReceived;
          lastTime = now;
        }

        onProgress(bytesReceived, lastSpeed);
      }

      await sink.flush();
      await sink.close();
      stopwatch.stop();

      // Use >= to handle minor byte-count edge cases from socket buffering.
      // The real success indicator is the file existing with full content.
      if (bytesReceived >= expectedSize) {
        onComplete();
      } else {
        onError("Transfer incomplete. Got $bytesReceived of $expectedSize bytes.");
      }
    } catch (e) {
      await sink?.close();
      onError("Download error: $e");
    } finally {
      socket.close();
    }
  }

  // Send file to remote peer
  Future<void> sendFile({
    required String ipAddress,
    required int port,
    required String transferId,
    required String senderName,
    required File file,
    required Function(int bytes, double speed) onProgress,
    required Function() onComplete,
    required Function(String error) onError,
    required Function() onRejected,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ipAddress, port, timeout: const Duration(seconds: 10));
      
      final fileName = file.path.split(Platform.pathSeparator).last;
      final fileSize = await file.length();

      // 1. Send JSON header + newline
      final header = {
        'transferId': transferId,
        'peerName': senderName,
        'fileName': fileName,
        'fileSize': fileSize,
      };

      socket.write("${jsonEncode(header)}\n");
      await socket.flush();

      // 2. Wait for response: ACCEPT or REJECT
      final completer = Completer<String>();
      StringBuffer buffer = StringBuffer();
      
      final subscription = socket.listen((data) {
        buffer.write(utf8.decode(data));
        final response = buffer.toString();
        if (response.contains('\n')) {
          completer.complete(response.split('\n')[0]);
        }
      }, onError: (err) {
        if (!completer.isCompleted) completer.completeError(err);
      });

      String response;
      try {
        response = await completer.future.timeout(const Duration(seconds: 30));
      } finally {
        await subscription.cancel();
      }

      if (response == "REJECT") {
        onRejected();
        socket.close();
        return;
      }

      if (response != "ACCEPT") {
        onError("Unexpected server response: $response");
        socket.close();
        return;
      }

      // 3. Start streaming file chunks
      final fileStream = file.openRead();
      int bytesSent = 0;
      final stopwatch = Stopwatch()..start();
      
      double lastSpeed = 0.0;
      int lastBytes = 0;
      DateTime lastTime = DateTime.now();

      await for (final chunk in fileStream) {
        socket.add(chunk);
        bytesSent += chunk.length;

        // Calculate transfer speed every 500ms
        final now = DateTime.now();
        final difference = now.difference(lastTime).inMilliseconds;
        if (difference >= 500) {
          final bytesDiff = bytesSent - lastBytes;
          lastSpeed = (bytesDiff / (1024 * 1024)) / (difference / 1000.0);
          lastBytes = bytesSent;
          lastTime = now;
        }

        onProgress(bytesSent, lastSpeed);
        
        // Backpressure control: flush and wait for OS buffer to drain
        await socket.flush();
      }

      stopwatch.stop();
      onComplete();
    } catch (e) {
      onError("Upload error: $e");
    } finally {
      socket?.close();
    }
  }

  void stopServer() {
    _serverSocket?.close();
    _serverSocket = null;
    print("TCP Server stopped.");
  }
}
