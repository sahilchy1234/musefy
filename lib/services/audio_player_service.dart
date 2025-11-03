import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/music_track.dart';
import 'youtube_service.dart';

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal() {
    _init();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  final YouTubeService _youtubeService = YouTubeService();
  final YoutubeExplode _youtubeExplode = YoutubeExplode();
  
  MusicTrack? _currentTrack;
  List<MusicTrack> _playlist = [];
  int _currentIndex = 0;
  bool _isInitialized = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  
  // Cache directory for downloaded audio files
  Directory? _cacheDir;

  MusicTrack? get currentTrack => _currentTrack;
  List<MusicTrack> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _audioPlayer.playing;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  Future<void> _init() async {
    if (_isInitialized) return;
    
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      
      // Initialize cache directory
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory('${tempDir.path}/audio_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      
      _isInitialized = true;
      
      // Listen to player state
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          print('⏭️ Track completed, playing next...');
          playNext();
        }
        notifyListeners();
      });
      
      print('✅ Audio player initialized');
      print('📁 Cache directory: ${_cacheDir!.path}');
    } catch (e) {
      print('❌ Error initializing audio player: $e');
    }
  }

  /// Download audio using youtube-explode's built-in stream (more reliable)
  Future<File?> _downloadAudioFileViaExplode(String videoId) async {
    IOSink? sink;
    try {
      await _init();
      
      final fileName = '$videoId.m4a';
      final filePath = '${_cacheDir!.path}/$fileName';
      final file = File(filePath);
      
      // Check if file already exists in cache
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > 1024) {
          print('✅ Using cached audio file: $fileName (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
          return file;
        } else {
          print('⚠️ Deleting corrupted cache file: $fileName');
          await file.delete();
        }
      }
      
      print('⬇️ Downloading via youtube-explode: $fileName');
      _isDownloading = true;
      _downloadProgress = 0.0;
      notifyListeners();
      
      // Get stream manifest with retry logic
      print('🔍 Getting stream manifest...');
      StreamManifest? manifest;
      
      // Retry up to 3 times with increasing timeout
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          manifest = await _youtubeExplode.videos.streamsClient
              .getManifest(videoId)
              .timeout(Duration(seconds: 10 + (attempt * 5))); // 15s, 20s, 25s
          break; // Success, exit retry loop
        } catch (e) {
          print('⚠️ Manifest attempt $attempt failed: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt)); // Wait before retry
          } else {
            rethrow; // Final attempt failed
          }
        }
      }
      
      if (manifest == null) {
        throw Exception('Failed to get manifest after 3 attempts');
      }
      
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      
      print('📊 Stream info: ${(streamInfo.size.totalBytes / 1024 / 1024).toStringAsFixed(2)} MB, ${streamInfo.bitrate.kiloBitsPerSecond.toStringAsFixed(0)} kbps');
      
      // Download using youtube-explode's built-in downloader (handles auth automatically)
      print('🌐 Starting download stream...');
      final stream = _youtubeExplode.videos.streamsClient.get(streamInfo);
      sink = file.openWrite();
      var downloaded = 0;
      final totalBytes = streamInfo.size.totalBytes;
      var lastNotifyBytes = 0;
      
      // Add timeout to prevent hanging (increased to 60 seconds for slow connections)
      final streamWithTimeout = stream.timeout(
        const Duration(seconds: 60),
        onTimeout: (eventSink) {
          print('⏰ Stream timeout - no data received in 60 seconds');
          throw TimeoutException('Download stream timed out after 60 seconds');
        },
      );
      
      print('📦 Reading stream chunks...');
      try {
        await for (var chunk in streamWithTimeout) {
          sink.add(chunk);
          downloaded += chunk.length;
          
          _downloadProgress = downloaded / totalBytes;
          
          // Notify every 50KB for more frequent updates
          if (downloaded - lastNotifyBytes >= 51200 || _downloadProgress >= 0.99) {
            notifyListeners();
            lastNotifyBytes = downloaded;
            print('📥 Progress: ${(_downloadProgress * 100).toStringAsFixed(1)}% (${(downloaded / 1024 / 1024).toStringAsFixed(2)} MB / ${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB)');
          }
        }
      } catch (e) {
        print('❌ Stream reading error: $e');
        rethrow;
      }
      
      print('💾 Closing file...');
      await sink.close();
      sink = null;
      
      _isDownloading = false;
      _downloadProgress = 1.0;
      notifyListeners();
      
      final finalSize = await file.length();
      print('✅ Download complete: $fileName (${(finalSize / 1024 / 1024).toStringAsFixed(2)} MB)');
      
      return file;
    } catch (e, stackTrace) {
      print('❌ Error downloading via youtube-explode: $e');
      if (e is TimeoutException) {
        print('⏰ Download timed out - will try fallback method');
      }
      print('📍 Stack trace: ${stackTrace.toString().substring(0, 200)}...');
      
      // Clean up
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      
      _isDownloading = false;
      _downloadProgress = 0.0;
      notifyListeners();
      return null;
    }
  }

  /// Download audio file from URL with progress tracking (fallback method)
  Future<File?> _downloadAudioFile(String videoId, String audioUrl) async {
    try {
      await _init();
      
      final fileName = '$videoId.m4a';
      final filePath = '${_cacheDir!.path}/$fileName';
      final file = File(filePath);
      
      // Check if file already exists in cache
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > 1024) { // File must be at least 1KB
          print('✅ Using cached audio file: $fileName (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
          return file;
        } else {
          // Delete corrupted cache file
          print('⚠️ Deleting corrupted cache file: $fileName');
          await file.delete();
        }
      }
      
      print('⬇️ Downloading audio: $fileName');
      print('🔗 URL: ${audioUrl.substring(0, 100)}...');
      _isDownloading = true;
      _downloadProgress = 0.0;
      notifyListeners();
      
      // Download with progress tracking and proper headers
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(audioUrl));
        
        // Add required headers for YouTube downloads
        request.headers.addAll({
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'Connection': 'keep-alive',
          'Range': 'bytes=0-', // Support partial content
        });
        
        final response = await client.send(request);
        
        print('📥 Response status: ${response.statusCode}');
        
        if (response.statusCode != 200 && response.statusCode != 206) {
          throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
        }
        
        final contentLength = response.contentLength ?? 0;
        print('📊 Content length: ${(contentLength / 1024 / 1024).toStringAsFixed(2)} MB');
        
        final sink = file.openWrite();
        var downloaded = 0;
        var lastNotifyBytes = 0;
        
        await for (var chunk in response.stream) {
          sink.add(chunk);
          downloaded += chunk.length;
          
          if (contentLength > 0) {
            _downloadProgress = downloaded / contentLength;
            
            // Notify every 100KB or when complete
            if (downloaded - lastNotifyBytes >= 102400 || _downloadProgress >= 0.99) {
              notifyListeners();
              lastNotifyBytes = downloaded;
              print('📥 Progress: ${(_downloadProgress * 100).toStringAsFixed(1)}% (${(downloaded / 1024 / 1024).toStringAsFixed(2)} MB)');
            }
          }
        }
        
        await sink.close();
        
        _isDownloading = false;
        _downloadProgress = 1.0;
        notifyListeners();
        
        final finalSize = await file.length();
        print('✅ Download complete: $fileName (${(finalSize / 1024 / 1024).toStringAsFixed(2)} MB)');
        
        return file;
      } finally {
        client.close();
      }
    } catch (e, stackTrace) {
      print('❌ Error downloading audio: $e');
      print('📍 Stack trace: $stackTrace');
      _isDownloading = false;
      _downloadProgress = 0.0;
      notifyListeners();
      return null;
    }
  }

  Future<void> playTrack(MusicTrack track, {List<MusicTrack>? playlist, int? index}) async {
    try {
      await _init();
      
      _currentTrack = track;
      if (playlist != null) {
        _playlist = playlist;
        _currentIndex = index ?? 0;
      }

      print('🎵 Loading track: ${track.title}');
      notifyListeners();

      File? audioFile;

      // Method 1: Try using youtube-explode's built-in downloader (more reliable, handles auth)
      print('🔄 Attempting download via youtube-explode (Method 1)...');
      audioFile = await _downloadAudioFileViaExplode(track.id);
      
      // Method 2: If Method 1 fails, try HTTP download with custom headers
      if (audioFile == null) {
        print('🔄 Method 1 failed, trying HTTP download with headers (Method 2)...');
        
        // Get audio stream URL
        String? audioUrl;
        for (int attempt = 1; attempt <= 2; attempt++) {
          print('   Attempt $attempt to get audio URL...');
          audioUrl = await _youtubeService.getAudioStreamUrl(track.id);
          if (audioUrl != null) break;
          if (attempt < 2) {
            await Future.delayed(Duration(seconds: attempt));
          }
        }
        
        if (audioUrl != null) {
          audioFile = await _downloadAudioFile(track.id, audioUrl);
        }
      }
      
      // Check if download was successful
      if (audioFile == null) {
        print('❌ All download methods failed, trying next track...');
        await playNext();
        return;
      }

      // Verify file was downloaded successfully
      final fileSize = await audioFile.length();
      if (fileSize < 10240) { // File must be at least 10KB
        print('❌ Downloaded file too small ($fileSize bytes), trying next track...');
        await audioFile.delete();
        await playNext();
        return;
      }

      print('📁 Playing from file: ${audioFile.path} (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');

      // Play from local file
      await _audioPlayer.setFilePath(audioFile.path);
      await _audioPlayer.play();
      
      print('✅ Now playing: ${track.title}');
      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ Error playing track: $e');
      print('📍 Stack trace: $stackTrace');
      print('⏭️ Trying next track...');
      _isDownloading = false;
      _downloadProgress = 0.0;
      notifyListeners();
      await playNext();
    }
  }

  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      notifyListeners();
    } catch (e) {
      print('❌ Error pausing: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _audioPlayer.play();
      notifyListeners();
    } catch (e) {
      print('❌ Error resuming: $e');
    }
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> playNext() async {
    if (_playlist.isEmpty || _currentIndex >= _playlist.length - 1) {
      print('⚠️ No more tracks in playlist');
      return;
    }
    
    _currentIndex++;
    await playTrack(_playlist[_currentIndex], playlist: _playlist, index: _currentIndex);
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty || _currentIndex <= 0) {
      print('⚠️ Already at first track');
      return;
    }
    
    _currentIndex--;
    await playTrack(_playlist[_currentIndex], playlist: _playlist, index: _currentIndex);
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      print('❌ Error seeking: $e');
    }
  }

  void setPlaylist(List<MusicTrack> playlist, {int startIndex = 0}) {
    _playlist = playlist;
    _currentIndex = startIndex;
    notifyListeners();
  }

  void shufflePlaylist() {
    if (_playlist.isEmpty) return;
    _playlist.shuffle();
    _currentIndex = 0;
    notifyListeners();
  }

  /// Clear audio cache to free up storage
  Future<void> clearCache() async {
    try {
      if (_cacheDir != null && await _cacheDir!.exists()) {
        final files = _cacheDir!.listSync();
        for (var file in files) {
          if (file is File) {
            await file.delete();
          }
        }
        print('🗑️ Cache cleared: ${files.length} files deleted');
      }
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  /// Get cache size in MB
  Future<double> getCacheSize() async {
    try {
      if (_cacheDir != null && await _cacheDir!.exists()) {
        final files = _cacheDir!.listSync();
        var totalSize = 0;
        for (var file in files) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
        return totalSize / 1024 / 1024; // Convert to MB
      }
    } catch (e) {
      print('❌ Error getting cache size: $e');
    }
    return 0.0;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _youtubeExplode.close();
    super.dispose();
  }
}
