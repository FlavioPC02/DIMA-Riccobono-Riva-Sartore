enum TrailDownloadStatus {
  notDownloaded,
  downloading,
  available,
  failed,
}

class TrailDownloadState {
  final TrailDownloadStatus status;

  /// Valore tra 0 e 1. Null quando la percentuale non è disponibile.
  final double? progress;

  final String? error;

  const TrailDownloadState({
    required this.status,
    this.progress,
    this.error,
  });
}