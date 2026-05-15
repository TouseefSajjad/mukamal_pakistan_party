import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marquee/marquee.dart';
import 'package:mukammalpakistanparty/%20config/app_theme.dart';
import 'package:mukammalpakistanparty/menue/aboutparty.dart';
import 'package:mukammalpakistanparty/screens/home/Application%20screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

// ── Project imports (adjust paths to match your structure) ──────
import 'package:mukammalpakistanparty/screens/auth/login_screen.dart';


// ================================================================
//  EXTRA COLORS NOT COVERED BY AppTheme
//  (kept here so HomeScreen has zero raw Color literals scattered
//   throughout the widget tree — change once, applies everywhere)
// ================================================================
abstract class _Extra {
  // Deep forest green (darker than AppTheme.primaryGreen)
  static const deepForest   = Color(0xFF1B5E20);

  // Mid-range greens used for gradients / glows
  static const emeraldLight = Color(0xFF388E3C);
  static const emeraldGlow  = Color(0xFF66BB6A);

  // Gold family
  static const gold         = Color(0xFFD4AF37);
  static const goldLight    = Color(0xFFF5E27A);

  // Glass / overlay helpers
  static const glassWhite   = Color(0x1AFFFFFF);
  static const glassBorder  = Color(0x33FFFFFF);
  static const shadowGreen  = Color(0x332E7D32);

  // ── Gradients ──────────────────────────────────────────────────
  static const bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
    colors: [
      Color(0xFF245C2A),
      Color(0xFF2E7D32), // == AppTheme.primaryGreen
      Color(0xFF3E8E41),
      Color(0xFF245C2A),
    ],
  );

  static const cardGlass = LinearGradient(
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
    colors: [Color(0x22FFFFFF), Color(0x0DFFFFFF)],
  );
}

// ================================================================
//  HOME SCREEN
// ================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── Firebase / auth state ──
  User?                  _user;
  Map<String, dynamic>?  _userData;
  bool                   _loadingUser = true;

  // ── Banner carousel ──
  int                    _bannerIndex = 0;
  final CarouselSliderController _carouselCtrl = CarouselSliderController();

  // ── Animations ──
  late AnimationController _fadeCtrl;
  late AnimationController _rotateCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _rotateAnim;

  // ── Drawer key ──
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ================================================================
  @override
  void initState() {
    super.initState();
    _loadingUser = true;

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _rotateCtrl =
    AnimationController(vsync: this, duration: const Duration(seconds: 25))
      ..repeat();

    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _rotateAnim =
        Tween<double>(begin: 0, end: 2 * math.pi).animate(
            CurvedAnimation(parent: _rotateCtrl, curve: Curves.linear));

    _initUser();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  // ── Initialise Firebase user + Firestore profile ──────────────
  Future<void> _initUser() async {
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      if (mounted) {
        setState(() {
          _userData    = doc.data();
          _loadingUser = false;
        });
      }
    } else {
      if (mounted) setState(() => _loadingUser = false);
    }
    _fadeCtrl.forward();
  }

  // ── Navigate to Membership Application ───────────────────────
  void _goToApplication() {
    if (_user == null) {
      _showSnack('User not logged in');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              MembershipApplicationScreen(userId: _user!.uid)),
    );
  }

  // ── Logout ───────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm =
    await showDialog<bool>(context: context, builder: (_) => _LogoutDialog());
    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,

      // ── Premium Drawer ──────────────────────────────────────
      drawer: _AppDrawer(
        userData: _userData,
        user:     _user,
        onLogout: _logout,
      ),

      // ── Custom AppBar ────────────────────────────────────────
      appBar: _buildAppBar(),

      // ── Body ─────────────────────────────────────────────────
      body: Stack(
        children: [
          if (!_loadingUser) _AnimatedBg(rotateAnim: _rotateAnim),

          _loadingUser
              ? Container(
            color: _Extra.deepForest,
            child: const Center(
                child: CircularProgressIndicator(color: _Extra.gold)),
          )
              : _user == null
              ? const _NotLoggedIn()
              : FadeTransition(
            opacity: _fadeAnim,
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_Extra.deepForest, Color(0xFF0A5228)],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          border: const Border(
              bottom: BorderSide(color: _Extra.glassBorder, width: 0.8)),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.4),
                blurRadius: 16),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // ── Hamburger menu ──
                IconButton(
                  icon: const Icon(Icons.menu_rounded,
                      color: AppTheme.textOnPrimary, size: 26),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  tooltip: 'Menu',
                ),

                // ── Logo ──
                Image.asset(
                  'assets/logo.png',
                  height: 36,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.flag_rounded,
                      color: _Extra.gold,
                      size: 32),
                ),

                const SizedBox(width: 10),

                // ── Title block ──
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mukammal Pakistan Party',
                        style: GoogleFonts.playfairDisplay(
                            color: AppTheme.textOnPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'مکمل پاکستان پارٹی',
                        style: GoogleFonts.notoNaskhArabic(
                            color: _Extra.goldLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Main scrollable body ─────────────────────────────────────
  Widget _buildBody() {
    final topPad = MediaQuery.of(context).padding.top + 64;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              SizedBox(height: topPad),

              // 1 ── Greeting header
              _GreetingHeader(userData: _userData, user: _user),

              // 2 ── Marquee ticker
              const _MarqueeTicker(),

              const SizedBox(height: 24),

              // 3 ── Firebase Banner Carousel
              _BannerCarousel(
                index:    _bannerIndex,
                ctrl:     _carouselCtrl,
                onChange: (i) => setState(() => _bannerIndex = i),
              ),

              const SizedBox(height: 28),

              // 4 ── Apply Membership CTA
              _MembershipCTA(onTap: _goToApplication),

              const SizedBox(height: 24),

              // 5 ── Quick-action grid (placeholder spacing)
              const SizedBox(height: 24),
              const SizedBox(height: 24),

              // 6 ── Party slogan card
              const _SloganCard(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================
//  ANIMATED BACKGROUND
// ================================================================
class _AnimatedBg extends StatelessWidget {
  final Animation<double> rotateAnim;
  const _AnimatedBg({required this.rotateAnim});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox.expand(
      child: Stack(
        children: [
          // Main gradient
          Container(decoration: const BoxDecoration(gradient: _Extra.bgGradient)),

          // Rotating top-right orb
          AnimatedBuilder(
            animation: rotateAnim,
            builder: (_, __) => Positioned(
              top: -100, right: -100,
              child: Transform.rotate(
                angle: rotateAnim.value,
                child: Container(
                  width: 320, height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      _Extra.emeraldLight.withOpacity(0.18),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),
          ),

          // Static bottom-left orb
          Positioned(
            bottom: size.height * 0.05, left: -80,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _Extra.gold.withOpacity(0.07),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // Grid
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _GridPainter(),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _Extra.emeraldLight.withOpacity(0.035)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width;  x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// ================================================================
//  GREETING HEADER
// ================================================================
class _GreetingHeader extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final User? user;
  const _GreetingHeader({required this.userData, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = userData?['name'] as String? ??
        user?.displayName ??
        user?.email?.split('@').first ??
        'Member';

    final hour     = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: GoogleFonts.lato(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: GoogleFonts.playfairDisplay(
                      color: AppTheme.textOnPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Avatar circle
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                AppTheme.primaryGreen,
                _Extra.emeraldLight,
              ]),
              border: Border.all(color: _Extra.gold, width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: _Extra.emeraldGlow.withOpacity(0.4),
                    blurRadius: 14),
              ],
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'M',
                style: GoogleFonts.playfairDisplay(
                    color: AppTheme.textOnPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
//  MARQUEE TICKER
// ================================================================
class _MarqueeTicker extends StatelessWidget {
  const _MarqueeTicker();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.primaryGreen.withOpacity(0.5),
          _Extra.deepForest.withOpacity(0.7),
          AppTheme.primaryGreen.withOpacity(0.5),
        ]),
        border: const Border.symmetric(
          horizontal: BorderSide(color: _Extra.glassBorder, width: 0.8),
        ),
      ),
      height: 42,
      child: Row(
        children: [
          // Label badge
          Container(
            margin:  const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _Extra.gold,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'LIVE',
              style: GoogleFonts.lato(
                  color: _Extra.deepForest,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1),
            ),
          ),

          Expanded(
            child: Marquee(
              text: '  مکمل پاکستان پارٹی کا نعرہ ایمان ، اتحاد ، تنظیم اور عدل  '
                  '★  ایک مضبوط، خودمختار اور متحد پاکستان کا وژن  '
                  '★  نوجوانوں کو بااختیار بنانا ہمارا مشن ہے  ★  ',
              style: GoogleFonts.notoNaskhArabic(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
              velocity:   40,
              blankSpace: 60,
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
//  FIREBASE BANNER CAROUSEL
// ================================================================
class _BannerCarousel extends StatelessWidget {
  final int index;
  final CarouselSliderController ctrl;
  final ValueChanged<int> onChange;

  const _BannerCarousel({
    required this.index,
    required this.ctrl,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('banners')
          .where('active', isEqualTo: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _BannerShimmer();
        }
        if (snap.hasError) {
          return const _BannerFallback(
            icon:    Icons.cloud_off_rounded,
            message: 'Could not load banners.\nCheck your connection.',
          );
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return const _BannerFallback(
            icon:    Icons.image_not_supported_rounded,
            message: 'No announcements right now.\nCheck back soon!',
          );
        }

        final banners = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return _BannerModel(
            title:    data['title']    as String? ?? '',
            imageUrl: data['imageUrl'] as String? ?? '',
          );
        }).toList();

        return Column(
          children: [
            // ── Carousel ──
            CarouselSlider.builder(
              carouselController: ctrl,
              itemCount: banners.length,
              options: CarouselOptions(
                height:                    200,
                autoPlay:                  true,
                autoPlayInterval:          const Duration(seconds: 4),
                autoPlayCurve:             Curves.easeInOutCubic,
                autoPlayAnimationDuration: const Duration(milliseconds: 700),
                enlargeCenterPage:         true,
                enlargeFactor:             0.18,
                viewportFraction:          0.88,
                onPageChanged:             (i, _) => onChange(i),
              ),
              itemBuilder: (ctx, i, _) => _BannerCard(banner: banners[i]),
            ),

            const SizedBox(height: 12),

            // ── Dot indicators ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(banners.length, (i) {
                final active = i == index;
                return GestureDetector(
                  onTap: () => ctrl.animateToPage(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin:  const EdgeInsets.symmetric(horizontal: 4),
                    width:   active ? 22 : 8,
                    height:  8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: active ? _Extra.gold : _Extra.glassBorder,
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _BannerModel {
  final String title;
  final String imageUrl;
  const _BannerModel({required this.title, required this.imageUrl});
}

// Individual banner card
class _BannerCard extends StatelessWidget {
  final _BannerModel banner;
  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Extra.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
              color:     AppTheme.primaryGreen.withOpacity(0.3),
              blurRadius: 20,
              offset:    const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Banner image
          CachedNetworkImage(
            imageUrl: banner.imageUrl,
            fit:      BoxFit.cover,
            placeholder: (_, __) =>
                _shimmerBox(double.infinity, double.infinity),
            errorWidget: (_, __, ___) => Container(
              color: AppTheme.primaryGreen.withOpacity(0.2),
              child: const Icon(Icons.broken_image_rounded,
                  color: AppTheme.textSecondary, size: 48),
            ),
          ),

          // Gradient overlay
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 30, 14, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.bottomCenter,
                  end:    Alignment.topCenter,
                  colors: [Color(0xDD042A12), Colors.transparent],
                ),
              ),
              child: banner.title.isNotEmpty
                  ? Text(
                banner.title,
                style: GoogleFonts.playfairDisplay(
                    color: AppTheme.textOnPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              )
                  : const SizedBox.shrink(),
            ),
          ),

          // Party watermark badge
          Positioned(
            top: 10, right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _Extra.gold.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'MPP',
                style: GoogleFonts.lato(
                    color: _Extra.deepForest,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Shimmer skeleton while banners load
class _BannerShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor:      AppTheme.primaryGreen.withOpacity(0.3),
      highlightColor: _Extra.emeraldLight.withOpacity(0.5),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.4),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

// Fallback when no banners
class _BannerFallback extends StatelessWidget {
  final IconData icon;
  final String   message;
  const _BannerFallback({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.symmetric(horizontal: 24),
      height:  160,
      decoration: BoxDecoration(
        gradient: _Extra.cardGlass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Extra.glassBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
                color: AppTheme.textSecondary, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ================================================================
//  MEMBERSHIP CTA  (premium animated button)
// ================================================================
class _MembershipCTA extends StatefulWidget {
  final VoidCallback onTap;
  const _MembershipCTA({required this.onTap});

  @override
  State<_MembershipCTA> createState() => _MembershipCTAState();
}

class _MembershipCTAState extends State<_MembershipCTA>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTapDown:  (_) => _ctrl.forward(),
        onTapUp:    (_) { _ctrl.reverse(); widget.onTap(); },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (_, child) =>
              Transform.scale(scale: _scaleAnim.value, child: child),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_Extra.gold, Color(0xFFF5C842), _Extra.gold]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: _Extra.gold.withOpacity(0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.upload_file_rounded,
                    color: _Extra.deepForest, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Apply for Membership',
                  style: GoogleFonts.playfairDisplay(
                      color: _Extra.deepForest,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
//  QUICK ACTIONS GRID
// ================================================================

// ================================================================
//  SLOGAN CARD
// ================================================================
class _SloganCard extends StatelessWidget {
  const _SloganCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:   const EdgeInsets.symmetric(horizontal: 20),
      padding:  const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen.withOpacity(0.35),
            _Extra.deepForest.withOpacity(0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _Extra.gold.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
              color:      AppTheme.primaryGreen.withOpacity(0.2),
              blurRadius: 24,
              offset:     const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
                  (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child:   const Icon(Icons.star, color: _Extra.gold, size: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Together We Build a Complete Pakistan',
            style: GoogleFonts.playfairDisplay(
                color:      AppTheme.textOnPrimary,
                fontSize:   17,
                fontWeight: FontWeight.w700,
                fontStyle:  FontStyle.italic,
                height:     1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Gold divider rule
          Container(
            height: 1.5,
            width:  50,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [
                Colors.transparent,
                _Extra.gold,
                Colors.transparent,
              ]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text(
            'آئیں مل کر ایک مکمل پاکستان تعمیر کریں',
            style: GoogleFonts.notoNaskhArabic(
                color:    AppTheme.textSecondary,
                fontSize: 14,
                height:   2),
            textDirection: TextDirection.rtl,
            textAlign:     TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ================================================================
//  NAVIGATION DRAWER
// ================================================================
class _AppDrawer extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final User?        user;
  final VoidCallback onLogout;

  const _AppDrawer({
    required this.userData,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final name = userData?['name'] as String? ??
        user?.displayName ??
        user?.email?.split('@').first ??
        'Member';
    final email = user?.email ?? '';

    return Drawer(
      width: 290,
      child: Container(
        decoration: const BoxDecoration(gradient: _Extra.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              _DrawerHeader(name: name, email: email),

              const SizedBox(height: 16),

              // ── Menu items ──
              _DrawerItem(
                icon:     Icons.account_balance_rounded,
                label:    'About Party',
                sublabel: 'Learn about MPP',
                color:    const Color(0xFF27AE60),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AboutPartyScreen()),
                  );
                },
              ),

              _DrawerItem(
                icon:     Icons.upload_file_rounded,
                label:    'Apply Membership',
                sublabel: 'Join the movement',
                color:    _Extra.gold,
                onTap: () {
                  Navigator.pop(context);
                  if (user != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              MembershipApplicationScreen(userId: user!.uid)),
                    );
                  }
                },
              ),



              const Spacer(),

              Divider(
                  color:    _Extra.glassBorder,
                  thickness: 0.8,
                  indent:   20,
                  endIndent: 20),

              _DrawerItem(
                icon:     Icons.logout_rounded,
                label:    'Logout',
                sublabel: 'Sign out of your account',
                color:    AppTheme.criticalRed,
                onTap:    () { Navigator.pop(context); onLogout(); },
              ),

              const SizedBox(height: 16),

              Text(
                'v1.0.0  •  Mukammal Pakistan Party',
                style: GoogleFonts.lato(
                    color:    AppTheme.textSecondary.withOpacity(0.5),
                    fontSize: 10),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final String name;
  final String email;
  const _DrawerHeader({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withOpacity(0.5),
            _Extra.deepForest.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        border: const Border(
            bottom: BorderSide(color: _Extra.glassBorder, width: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [AppTheme.primaryGreen, _Extra.emeraldLight]),
              border: Border.all(color: _Extra.gold, width: 2),
              boxShadow: [
                BoxShadow(
                    color:      _Extra.emeraldGlow.withOpacity(0.4),
                    blurRadius: 16),
              ],
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'M',
                style: GoogleFonts.playfairDisplay(
                    color:      AppTheme.textOnPrimary,
                    fontSize:   26,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            name,
            style: GoogleFonts.playfairDisplay(
                color:      AppTheme.textOnPrimary,
                fontSize:   18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),

          Text(
            email,
            style:    GoogleFonts.lato(
                color: AppTheme.textSecondary, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 10),

          // Member badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        _Extra.gold.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: const []),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   sublabel;
  final Color    color;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:            onTap,
      splashColor:      color.withOpacity(0.1),
      highlightColor:   color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color:  color.withOpacity(0.15),
                border: Border.all(
                    color: color.withOpacity(0.35), width: 1),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.lato(
                        color:      AppTheme.textPrimary,
                        fontSize:   14,
                        fontWeight: FontWeight.w700),
                  ),
                  Text(
                    sublabel,
                    style: GoogleFonts.lato(
                        color:    AppTheme.textSecondary,
                        fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ================================================================
//  LOGOUT CONFIRMATION DIALOG
// ================================================================
class _LogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF063D1C), Color(0xFF042A12)],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _Extra.glassBorder, width: 1),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(0.4),
                blurRadius: 30),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:  AppTheme.criticalRed.withOpacity(0.15),
                border: Border.all(
                    color: AppTheme.criticalRed.withOpacity(0.5)),
              ),
              child: Icon(Icons.logout_rounded,
                  color: AppTheme.criticalRed, size: 28),
            ),
            const SizedBox(height: 16),

            Text(
              'Logout?',
              style: GoogleFonts.playfairDisplay(
                  color:      AppTheme.textOnPrimary,
                  fontSize:   20,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to sign out of your account?',
              style: GoogleFonts.lato(
                  color:    AppTheme.textSecondary,
                  fontSize: 13,
                  height:   1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                // Cancel
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _Extra.glassBorder),
                        color: _Extra.glassWhite,
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.lato(
                              color:      AppTheme.textPrimary,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Confirm
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.criticalRed,
                        boxShadow: [
                          BoxShadow(
                              color:      AppTheme.criticalRed.withOpacity(0.3),
                              blurRadius: 12),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Logout',
                          style: GoogleFonts.lato(
                              color:      AppTheme.textOnPrimary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
//  NOT-LOGGED-IN PLACEHOLDER
// ================================================================
class _NotLoggedIn extends StatelessWidget {
  const _NotLoggedIn();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded,
                color: AppTheme.textSecondary, size: 56),
            const SizedBox(height: 16),
            Text(
              'Not Logged In',
              style: GoogleFonts.playfairDisplay(
                  color:      AppTheme.textOnPrimary,
                  fontSize:   22,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Please log in to continue.',
              style: GoogleFonts.lato(
                  color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper ──────────────────────────────────────────────────────
Widget _shimmerBox(double w, double h) => Container(
    width:  w,
    height: h,
    color:  AppTheme.primaryGreen.withOpacity(0.3));