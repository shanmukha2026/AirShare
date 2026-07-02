// lib/models/transfer.dart

enum TransferStatus {
  pending,
  transferring,
  completed,
  failed,
  rejected,
}

class FileTransfer {
  final String id;
  final String fileName;
  final int fileSize; // in bytes
  final int bytesTransferred; // in bytes
  final double speed; // in MB/s
  final bool isDownload;
  final TransferStatus status;
  final String peerName;
  final String? errorMessage;

  FileTransfer({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.bytesTransferred,
    required this.speed,
    required this.isDownload,
    required this.status,
    required this.peerName,
    this.errorMessage,
  });

  double get progress {
    if (fileSize == 0) return 0.0;
    return bytesTransferred / fileSize;
  }

  FileTransfer copyWith({
    String? id,
    String? fileName,
    int? fileSize,
    int? bytesTransferred,
    double? speed,
    bool? isDownload,
    TransferStatus? status,
    String? peerName,
    String? errorMessage,
  }) {
    return FileTransfer(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      speed: speed ?? this.speed,
      isDownload: isDownload ?? this.isDownload,
      status: status ?? this.status,
      peerName: peerName ?? this.peerName,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
