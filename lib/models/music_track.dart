class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final String videoUrl;
  final Duration duration;

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.duration,
  });

  factory MusicTrack.fromYouTube(dynamic video) {
    String title = video.title ?? 'Unknown Title';
    String artist = video.author ?? 'Unknown Artist';
    
    // Try to separate artist and title if in "Artist - Title" format
    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      artist = parts[0].trim();
      title = parts.length > 1 ? parts[1].trim() : title;
    }

    return MusicTrack(
      id: video.id.value,
      title: title,
      artist: artist,
      thumbnailUrl: video.thumbnails.highResUrl ?? video.thumbnails.mediumResUrl ?? '',
      videoUrl: 'https://youtube.com/watch?v=${video.id.value}',
      duration: video.duration ?? Duration.zero,
    );
  }

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}

