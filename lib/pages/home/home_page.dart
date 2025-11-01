import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/music_track.dart';
import '../../services/youtube_service.dart';
import '../../services/audio_player_service.dart';
import '../../widgets/music_player_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final YouTubeService _youtubeService = YouTubeService();
  final AudioPlayerService _playerService = AudioPlayerService();
  final TextEditingController _searchController = TextEditingController();

  List<MusicTrack> _trendingTracks = [];
  List<MusicTrack> _recommendedTracks = [];
  List<MusicTrack> _searchResults = [];
  bool _isLoadingTrending = true;
  bool _isLoadingRecommended = true;
  bool _isSearching = false;
  String _selectedCategory = '';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    
    _loadMusic();
    _fadeController.forward();
  }

  Future<void> _loadMusic() async {
    setState(() {
      _isLoadingTrending = true;
      _isLoadingRecommended = true;
    });

    final trending = await _youtubeService.getTrendingMusic();
    final recommended = await _youtubeService.getRecommendedMusic();

    setState(() {
      _trendingTracks = trending;
      _recommendedTracks = recommended;
      _isLoadingTrending = false;
      _isLoadingRecommended = false;
    });
  }

  Future<void> _searchMusic(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    
    final results = await _youtubeService.searchMusic(query);
    
    setState(() {
      _searchResults = results;
    });
  }

  Future<void> _loadCategoryMusic(String category) async {
    setState(() {
      _selectedCategory = category;
      _isSearching = true;
    });

    final results = await _youtubeService.getMusicByCategory(category);
    
    setState(() {
      _searchResults = results;
    });
  }

  void _playTrack(MusicTrack track, List<MusicTrack> playlist, int index) async {
    try {
      await _playerService.playTrack(track, playlist: playlist, index: index);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎵 Now playing: ${track.title}'),
          backgroundColor: const Color(0xFF1DB954),
          duration: const Duration(seconds: 2),
        ),
      );
      
      setState(() {}); // Refresh to update playing indicator
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to play ${track.title}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = _playerService.currentTrack;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF121212),
                  Color(0xFF0A0E27),
                ],
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Search Bar
                _buildSearchBar(),

                // Categories
                _buildCategories(),

                // Content
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _isSearching
                        ? _buildSearchResults()
                        : _buildHomeContent(),
                  ),
                ),

                // Add spacing for player bar if track is playing
                if (currentTrack != null) const SizedBox(height: 80),
              ],
            ),
          ),

          // Mini Player Bar
          if (currentTrack != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: MusicPlayerBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1DB954), Color(0xFF1ED760)],
              ),
            ),
            child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            'Musefy',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          // Profile Icon
          IconButton(
            icon: const Icon(Icons.person_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search for music...',
            hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1DB954)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _searchMusic('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
          onChanged: _searchMusic,
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _youtubeService.categories.length,
        itemBuilder: (context, index) {
          final category = _youtubeService.categories[index];
          final isSelected = _selectedCategory == category;
          
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected
                    ? const Color(0xFF1DB954)
                    : Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF1DB954)
                        : Colors.white.withOpacity(0.2),
                  ),
                ),
                elevation: 0,
              ),
              onPressed: () => _loadCategoryMusic(category),
              child: Text(
                category,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: _loadMusic,
      color: const Color(0xFF1DB954),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trending Section
            _buildSectionHeader('Trending Now', Icons.trending_up_rounded),
            _isLoadingTrending
                ? _buildLoadingTrackList()
                : _buildTrackList(_trendingTracks),

            const SizedBox(height: 24),

            // Recommended Section
            _buildSectionHeader('Recommended for You', Icons.recommend_rounded),
            _isLoadingRecommended
                ? _buildLoadingTrackList()
                : _buildTrackList(_recommendedTracks),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildTrackItem(_searchResults[index], _searchResults, index);
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1DB954), size: 28),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackList(List<MusicTrack> tracks) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          return _buildTrackCard(tracks[index], tracks, index);
        },
      ),
    );
  }

  Widget _buildTrackCard(MusicTrack track, List<MusicTrack> playlist, int index) {
    final isPlaying = _playerService.currentTrack?.id == track.id;

    return GestureDetector(
      onTap: () => _playTrack(track, playlist, index),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: track.thumbnailUrl,
                    width: 160,
                    height: 120,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[800],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.music_note, size: 40),
                    ),
                  ),
                ),
                if (isPlaying)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.equalizer_rounded,
                          color: Color(0xFF1DB954),
                          size: 40,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackItem(MusicTrack track, List<MusicTrack> playlist, int index) {
    final isPlaying = _playerService.currentTrack?.id == track.id;

    return GestureDetector(
      onTap: () => _playTrack(track, playlist, index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPlaying
                ? const Color(0xFF1DB954)
                : Colors.white.withOpacity(0.1),
            width: isPlaying ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: track.thumbnailUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[800],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.music_note, size: 30),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Duration and Play Button
            Column(
              children: [
                if (isPlaying)
                  const Icon(
                    Icons.equalizer_rounded,
                    color: Color(0xFF1DB954),
                    size: 24,
                  )
                else
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                const SizedBox(height: 4),
                Text(
                  track.formattedDuration,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingTrackList() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 16),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[800]!,
              highlightColor: Colors.grey[700]!,
              child: Column(
                children: [
                  Container(
                    width: 160,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 140,
                    height: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 100,
                    height: 10,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

