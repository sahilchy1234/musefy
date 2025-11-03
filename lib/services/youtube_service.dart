import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/music_track.dart';

class YouTubeService {
  final YoutubeExplode _youtubeExplode = YoutubeExplode();

  // Embeddable music categories (copyright-free sources)
  final List<String> _musicCategories = [
    'NCS Release',
    'Chill Music',
    'Gaming Music',
    'Study Music',
    'Lofi Beats',
    'Electronic Music',
    'Trap Music NCS',
    'EDM Mix',
    'Royalty Free Music',
    'Background Music',
  ];

  List<String> get categories => _musicCategories;

  /// Search for music tracks
  Future<List<MusicTrack>> searchMusic(String query) async {
    try {
      print('Searching for: $query');
      
      // Search for "audio" versions from "Topic" channels which are usually embeddable
      final searchQuery = '$query audio';
      final searchList = await _youtubeExplode.search.search(searchQuery);
      final tracks = <MusicTrack>[];
      
      for (var video in searchList.take(50)) {
        try {
          final title = video.title.toLowerCase();
          final author = video.author.toLowerCase();
          
          // Prefer "Topic" channels (auto-generated, usually embeddable)
          // Or "Audio" versions
          // Skip official music videos (usually blocked)
          if (author.contains('topic') || 
              title.contains('audio') ||
              title.contains('lyrics') ||
              title.contains('lyric video')) {
            tracks.add(MusicTrack.fromYouTube(video));
            if (tracks.length >= 20) break;
          }
        } catch (e) {
          print('Error parsing video: $e');
        }
      }
      
      // If we didn't find enough Topic/Audio videos, add some regular ones
      if (tracks.length < 10) {
        print('Not enough embeddable videos found, adding more...');
        for (var video in searchList.take(30)) {
          if (tracks.length >= 20) break;
          try {
            final title = video.title.toLowerCase();
            if (!title.contains('official music video') && 
                !title.contains('official video')) {
              tracks.add(MusicTrack.fromYouTube(video));
            }
          } catch (e) {
            print('Error parsing video: $e');
          }
        }
      }
      
      print('Found ${tracks.length} results');
      return tracks;
    } catch (e) {
      print('Error searching music: $e');
      return [];
    }
  }

  /// Get trending music - using embeddable sources
  Future<List<MusicTrack>> getTrendingMusic() async {
    try {
      print('Getting trending music...');
      // Search for NCS (NoCopyrightSounds) - all embeddable
      return await _searchEmbeddableMusic('NCS music');
    } catch (e) {
      print('Error getting trending: $e');
      return [];
    }
  }

  /// Get music by category
  Future<List<MusicTrack>> getMusicByCategory(String category) async {
    return await _searchEmbeddableMusic(category);
  }

  /// Get recommended music (mix of popular tracks)
  Future<List<MusicTrack>> getRecommendedMusic() async {
    try {
      print('Getting recommended music...');
      // Use Audio Library - YouTube's free music collection
      return await _searchEmbeddableMusic('Audio Library music');
    } catch (e) {
      print('Error getting recommended music: $e');
      return [];
    }
  }

  /// Search specifically for embeddable music
  Future<List<MusicTrack>> _searchEmbeddableMusic(String query) async {
    try {
      print('Searching embeddable music: $query');
      
      final searchList = await _youtubeExplode.search.search(query);
      final tracks = <MusicTrack>[];
      
      for (var video in searchList.take(30)) {
        try {
          final author = video.author.toLowerCase();
          
          // Only include channels known for embeddable content
          if (author.contains('ncs') || 
              author.contains('nocopyright') ||
              author.contains('audio library') ||
              author.contains('royalty free') ||
              author.contains('copyright free') ||
              author.contains('topic')) {
            tracks.add(MusicTrack.fromYouTube(video));
            if (tracks.length >= 20) break;
          }
        } catch (e) {
          print('Error parsing video: $e');
        }
      }
      
      print('Found ${tracks.length} embeddable tracks');
      return tracks;
    } catch (e) {
      print('Error searching embeddable music: $e');
      return [];
    }
  }

  /// Get playlist music
  Future<List<MusicTrack>> getPlaylistMusic(String playlistId) async {
    try {
      final playlist = await _youtubeExplode.playlists.get(playlistId);
      final tracks = <MusicTrack>[];
      var count = 0;
      
      await for (var video in _youtubeExplode.playlists.getVideos(playlist.id)) {
        if (count >= 20) break;
        try {
          tracks.add(MusicTrack.fromYouTube(video));
          count++;
        } catch (e) {
          print('Error parsing video: $e');
        }
      }
      
      return tracks;
    } catch (e) {
      print('Error getting playlist music: $e');
      return [];
    }
  }

  /// Get audio stream URL for playback
  Future<String?> getAudioStreamUrl(String videoId) async {
    try {
      print('🎬 Getting audio stream for video: $videoId');
      
      var manifest = await _youtubeExplode.videos.streamsClient.getManifest(videoId);
      
      // Try to get audio-only stream with highest bitrate
      var audioStreams = manifest.audioOnly;
      
      if (audioStreams.isEmpty) {
        print('❌ No audio-only streams available');
        return null;
      }
      
      // Sort by bitrate and get the best quality
      var audioStream = audioStreams.withHighestBitrate();
      
      print('✅ Audio stream found:');
      print('   - Bitrate: ${audioStream.bitrate.kiloBitsPerSecond.toStringAsFixed(0)} kbps');
      print('   - Size: ${(audioStream.size.totalBytes / 1024 / 1024).toStringAsFixed(2)} MB');
      print('   - Codec: ${audioStream.audioCodec}');
      print('   - Container: ${audioStream.container.name}');
      
      return audioStream.url.toString();
    } catch (e, stackTrace) {
      print('❌ Error getting audio stream: $e');
      print('📍 Stack trace: $stackTrace');
      return null;
    }
  }

  /// Download audio stream directly using youtube-explode
  Stream<List<int>>? getAudioStream(String videoId) {
    try {
      print('🎬 Getting direct audio stream for video: $videoId');
      return _youtubeExplode.videos.streamsClient.get(
        _youtubeExplode.videos.streamsClient.getManifest(videoId).then(
          (manifest) => manifest.audioOnly.withHighestBitrate(),
        ) as dynamic,
      );
    } catch (e) {
      print('❌ Error getting direct audio stream: $e');
      return null;
    }
  }

  void dispose() {
    _youtubeExplode.close();
  }
}

