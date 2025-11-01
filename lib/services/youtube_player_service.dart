import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../models/music_track.dart';

class YouTubePlayerService extends ChangeNotifier {
  static final YouTubePlayerService _instance = YouTubePlayerService._internal();
  factory YouTubePlayerService() => _instance;
  YouTubePlayerService._internal();

  YoutubePlayerController? _controller;
  MusicTrack? _currentTrack;
  List<MusicTrack> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isInitialized = false;
  int _errorCount = 0; // Track consecutive errors

  YoutubePlayerController? get controller => _controller;
  MusicTrack? get currentTrack => _currentTrack;
  List<MusicTrack> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isInitialized => _isInitialized;

  void initialize() {
    if (_controller == null) {
      _controller = YoutubePlayerController(
        params: const YoutubePlayerParams(
          showControls: false,
          mute: false,
          showFullscreenButton: false,
          loop: false,
          enableCaption: false,
          enableJavaScript: true,
          playsInline: true,
          strictRelatedVideos: true,
          pointerEvents: PointerEvents.none,
        ),
      );
      
      // Set up state listener
      _controller!.listen((event) {
        final state = event.playerState;
        print('📺 Player state: $state');
        
        // Check for errors
        if (event.hasError) {
          print('❌ YouTube Player Error: ${event.error}');
          _errorCount++;
          
          if (_errorCount >= 10) {
            print('⚠️ Too many consecutive errors. Stopping auto-skip.');
            _isPlaying = false;
            notifyListeners();
            return;
          }
          
          print('⏭️ Skipping to next track due to error... (attempt $_errorCount/10)');
          playNext();
          return;
        }
        
        if (state == PlayerState.playing) {
          _errorCount = 0; // Reset error count on successful playback
          if (!_isPlaying) {
            _isPlaying = true;
            notifyListeners();
            print('🎵 Playback confirmed - audio is playing!');
          }
        } else if (state == PlayerState.paused) {
          if (_isPlaying) {
            _isPlaying = false;
            notifyListeners();
            print('⏸️ Playback paused');
          }
        } else if (state == PlayerState.ended) {
          print('⏭️ Track ended, playing next...');
          playNext();
        } else if (state == PlayerState.unStarted) {
          // If video stays unStarted for too long, it might be blocked
          Future.delayed(const Duration(seconds: 5), () {
            if (_controller != null) {
              _controller!.playerState.then((checkState) {
                if (checkState == PlayerState.unStarted || checkState == PlayerState.cued) {
                  print('⚠️ Video failed to start (possibly blocked). Trying next track...');
                  playNext();
                }
              });
            }
          });
        }
      });
      
      _isInitialized = true;
      notifyListeners();
      print('✅ YouTube player initialized');
    }
  }

  Future<void> playTrack(MusicTrack track, {List<MusicTrack>? playlist, int? index}) async {
    try {
      if (_controller == null) {
        initialize();
        // Give controller time to initialize
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _currentTrack = track;
      _isPlaying = true; // Set to true immediately for UI

      if (playlist != null) {
        _playlist = playlist;
        _currentIndex = index ?? 0;
        _errorCount = 0; // Reset error count for new playlist
      }

      print('🎵 Loading video: ${track.id}');
      notifyListeners();
      
      // Load and autoplay
      _controller!.loadVideoById(
        videoId: track.id,
        startSeconds: 0,
      );
      
      print('✅ Now playing: ${track.title}');
      
      // Try to force play after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        print('▶️ Attempting to start playback...');
        _controller!.playVideo();
      });
      
      // Try again after longer delay
      Future.delayed(const Duration(milliseconds: 1500), () {
        print('▶️ Second play attempt...');
        _controller!.playVideo();
      });
      
      // And one more time
      Future.delayed(const Duration(milliseconds: 3000), () {
        print('▶️ Third play attempt...');
        _controller!.playVideo();
      });
    } catch (e) {
      print('❌ Error playing track: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (_controller != null) {
      await _controller!.pauseVideo();
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> resume() async {
    if (_controller != null) {
      await _controller!.playVideo();
      _isPlaying = true;
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> playNext() async {
    if (_playlist.isEmpty || _currentIndex >= _playlist.length - 1) return;
    
    _currentIndex++;
    await playTrack(_playlist[_currentIndex], playlist: _playlist, index: _currentIndex);
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty || _currentIndex <= 0) return;
    
    _currentIndex--;
    await playTrack(_playlist[_currentIndex], playlist: _playlist, index: _currentIndex);
  }

  Future<void> seekTo(Duration position) async {
    if (_controller != null) {
      await _controller!.seekTo(seconds: position.inSeconds.toDouble());
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

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }
}

