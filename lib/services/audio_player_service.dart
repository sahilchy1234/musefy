import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
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
  
  MusicTrack? _currentTrack;
  List<MusicTrack> _playlist = [];
  int _currentIndex = 0;
  bool _isInitialized = false;

  MusicTrack? get currentTrack => _currentTrack;
  List<MusicTrack> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _audioPlayer.playing;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  Future<void> _init() async {
    if (_isInitialized) return;
    
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
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
    } catch (e) {
      print('❌ Error initializing audio player: $e');
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

      // Get audio stream URL
      final audioUrl = await _youtubeService.getAudioStreamUrl(track.id);
      
      if (audioUrl == null) {
        print('❌ Could not get audio URL, trying next track...');
        await playNext();
        return;
      }

      print('🔗 Audio URL obtained: ${audioUrl.substring(0, 50)}...');

      // Set and play audio
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
      
      print('✅ Now playing: ${track.title}');
      notifyListeners();
    } catch (e) {
      print('❌ Error playing track: $e');
      print('⏭️ Trying next track...');
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

