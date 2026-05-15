
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Entry point (for standalone testing) ────────────────────
void main() => runApp(const _AppShell());

class _AppShell extends StatelessWidget {
  const _AppShell();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: MPPColors.emerald,
        brightness: Brightness.dark,
      ),
    ),
    home: const AboutPartyScreen(),
  );
}

// ─── Brand Palette ────────────────────────────────────────────
abstract class MPPColors {
  static const Color deepForest = Color(0xFF042A12);
  static const Color emerald = Color(0xFF0D6B35);
  static const Color emeraldLight = Color(0xFF18A85A);
  static const Color emeraldGlow = Color(0xFF2ECC71);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF5E27A);
  static const Color pearl = Color(0xFFF8FAF9);
  static const Color snowWhite = Color(0xFFFFFFFF);
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color textPrimary = Color(0xFFEEF5F1);
  static const Color textSecondary = Color(0xFFADCCBB);
  static const Color shadowGreen = Color(0x6618A85A);

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepForest, Color(0xFF063D1C), Color(0xFF0A5228), Color(0xFF042A12)],
    stops: [0.0, 0.35, 0.70, 1.0],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x22FFFFFF), Color(0x0DFFFFFF)],
  );

  static const LinearGradient goldAccent = LinearGradient(
    colors: [gold, goldLight, gold],
  );
}

// ─── Text Styles ──────────────────────────────────────────────
abstract class MPPTextStyles {
  static TextStyle appBarTitle(BuildContext ctx) => GoogleFonts.playfairDisplay(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: MPPColors.snowWhite,
    letterSpacing: 0.5,
  );

  static TextStyle appBarSub(BuildContext ctx) => GoogleFonts.lato(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: MPPColors.goldLight,
    letterSpacing: 2.0,
  );

  static TextStyle chairmanName(BuildContext ctx) => GoogleFonts.playfairDisplay(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: MPPColors.snowWhite,
    height: 1.3,
  );

  static TextStyle chairmanRole(BuildContext ctx) => GoogleFonts.lato(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: MPPColors.goldLight,
    letterSpacing: 1.2,
  );

  static TextStyle sectionTitle(BuildContext ctx) => GoogleFonts.playfairDisplay(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: MPPColors.snowWhite,
    height: 1.4,
  );

  static TextStyle bodyUrdu(BuildContext ctx) => GoogleFonts.notoNaskhArabic(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: MPPColors.textSecondary,
    height: 2.0,
  );

  static TextStyle tagline(BuildContext ctx) => GoogleFonts.lato(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: MPPColors.deepForest,
    letterSpacing: 0.5,
  );

  static TextStyle valueLabel(BuildContext ctx) => GoogleFonts.notoNaskhArabic(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: MPPColors.snowWhite,
    height: 1.5,
  );

  static TextStyle footerEn(BuildContext ctx) => GoogleFonts.playfairDisplay(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: MPPColors.snowWhite,
    height: 1.5,
    fontStyle: FontStyle.italic,
  );

  static TextStyle footerUr(BuildContext ctx) => GoogleFonts.notoNaskhArabic(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: MPPColors.textSecondary,
    height: 2.0,
  );
}

// ─────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────
class AboutPartyScreen extends StatefulWidget {
  const AboutPartyScreen({super.key});
  @override
  State<AboutPartyScreen> createState() => _AboutPartyScreenState();
}

class _AboutPartyScreenState extends State<AboutPartyScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _slideCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _rotateCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))
      ..repeat();

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _rotateAnim = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(CurvedAnimation(parent: _rotateCtrl, curve: Curves.linear));

    Future.delayed(const Duration(milliseconds: 200), () {
      _fadeCtrl.forward();
      _slideCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          // Animated Background
          _AnimatedBackground(rotateAnim: _rotateAnim),

          // Content
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
                        bottom: 40,
                      ),
                      child: Column(
                        children: [
                          // Chairman Section
                          _ChairmanSection(pulseAnim: _pulseAnim),
                          const SizedBox(height: 32),

                          // About Party
                          _buildDelayedSection(
                            delay: 0,
                            child: const _AboutPartyCard(),
                          ),
                          const SizedBox(height: 20),

                          // Youth Business
                          _buildDelayedSection(
                            delay: 100,
                            child: const _YouthBusinessCard(),
                          ),
                          const SizedBox(height: 20),

                          // Chairman Message
                          _buildDelayedSection(
                            delay: 200,
                            child: const _ChairmanMessageCard(),
                          ),
                          const SizedBox(height: 32),

                          // Core Values
                          _buildDelayedSection(
                            delay: 300,
                            child: const _CoreValuesSection(),
                          ),
                          const SizedBox(height: 40),

                          // Footer
                          _buildDelayedSection(
                            delay: 400,
                            child: const _FooterQuote(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: ClipRRect(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [MPPColors.deepForest, Color(0xFF0A5228)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(color: MPPColors.glassBorder, width: 0.8),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Party Emblem
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [MPPColors.emerald, MPPColors.emeraldLight],
                      ),
                      border: Border.all(color: MPPColors.gold, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: MPPColors.emeraldGlow.withOpacity(0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.flag_rounded, color: MPPColors.snowWhite, size: 22),
                  ),
                  const SizedBox(width: 12),

                  // Titles
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mukammal Pakistan Party', style: MPPTextStyles.appBarTitle(context)),
                        const SizedBox(height: 2),
                        Text('ABOUT THE PARTY', style: MPPTextStyles.appBarSub(context)),
                      ],
                    ),
                  ),

                  // Crescent Icon
                  const Icon(Icons.star, color: MPPColors.goldLight, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDelayedSection({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (ctx, val, ch) => Opacity(
        opacity: val,
        child: Transform.translate(offset: Offset(0, (1 - val) * 30), child: ch),
      ),
      child: child,
    );
  }
}

// ─── Animated Background ─────────────────────────────────────
class _AnimatedBackground extends StatelessWidget {
  final Animation<double> rotateAnim;
  const _AnimatedBackground({required this.rotateAnim});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox.expand(
      child: Stack(
        children: [
          // Base gradient
          Container(decoration: const BoxDecoration(gradient: MPPColors.bgGradient)),

          // Rotating orb top-right
          AnimatedBuilder(
            animation: rotateAnim,
            builder: (ctx, _) => Positioned(
              top: -80,
              right: -80,
              child: Transform.rotate(
                angle: rotateAnim.value,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        MPPColors.emeraldLight.withOpacity(0.20),
                        MPPColors.emerald.withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Orb bottom-left
          Positioned(
            bottom: size.height * 0.1,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    MPPColors.gold.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Subtle grid pattern
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _GridPatternPainter(),
          ),
        ],
      ),
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MPPColors.emeraldLight.withOpacity(0.04)
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Chairman Section ─────────────────────────────────────────
class _ChairmanSection extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _ChairmanSection({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Glowing Avatar Frame
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (ctx, _) => Transform.scale(
              scale: pulseAnim.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          MPPColors.emeraldGlow.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Gold border ring
                  Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: MPPColors.gold, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: MPPColors.emeraldGlow.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: MPPColors.gold.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  // Inner glass ring
                  Container(
                    width: 126,
                    height: 126,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: MPPColors.glassBorder, width: 1),
                    ),
                  ),
                  // Chairman image / fallback
                  ClipOval(
                    child: SizedBox(
                      width: 118,
                      height: 118,
                      child: Image.asset(
                        'assets/chairmanpicture.png',
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [MPPColors.emerald, MPPColors.deepForest],
                            ),
                          ),
                          child: const Icon(Icons.person, size: 56, color: MPPColors.glassWhite),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Name
          Text('محمد عبدالمتین ہاشمی', style: MPPTextStyles.chairmanName(context), textAlign: TextAlign.center, textDirection: TextDirection.rtl),
          const SizedBox(height: 6),
          Text('CHAIRMAN — MUKAMMAL PAKISTAN PARTY', style: MPPTextStyles.chairmanRole(context), textAlign: TextAlign.center),
          const SizedBox(height: 16),

          // Tagline badge (English)
          _GlassBadge(text: 'Vision for a Strong & Self-Reliant Pakistan', icon: Icons.stars_rounded),
          const SizedBox(height: 10),

          // Tagline badge (Urdu)
          _GlassBadge(
            text: 'ایک مضبوط، خودمختار اور متحد پاکستان کا وژن',
            icon: Icons.flag_rounded,
            isUrdu: true,
          ),
        ],
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isUrdu;
  const _GlassBadge({required this.text, required this.icon, this.isUrdu = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MPPColors.gold.withOpacity(0.9), MPPColors.goldLight.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: MPPColors.gold.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isUrdu) ...[
            Icon(icon, size: 14, color: MPPColors.deepForest),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              style: MPPTextStyles.tagline(context).copyWith(
                fontFamily: isUrdu ? GoogleFonts.notoNaskhArabic().fontFamily : null,
                fontSize: isUrdu ? 13 : 12,
              ),
              textAlign: TextAlign.center,
              textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
            ),
          ),
          if (isUrdu) ...[
            const SizedBox(width: 6),
            Icon(icon, size: 14, color: MPPColors.deepForest),
          ],
        ],
      ),
    );
  }
}

// ─── Glass Card Base ──────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  const _GlassCard({required this.child, this.padding, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: MPPColors.cardGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: MPPColors.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: MPPColors.emerald.withOpacity(0.08), blurRadius: 30),
        ],
      ),
      child: child,
    );
  }
}

// ─── Section Header ───────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isUrdu;
  const _SectionHeader({required this.title, required this.icon, this.isUrdu = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MPPColors.emerald, MPPColors.emeraldLight],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: MPPColors.shadowGreen, blurRadius: 10)],
          ),
          child: Icon(icon, color: MPPColors.snowWhite, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: MPPTextStyles.sectionTitle(context),
            textAlign: isUrdu ? TextAlign.right : TextAlign.left,
            textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
          ),
        ),
      ],
    );
  }
}

// ─── Gold Divider ─────────────────────────────────────────────
class _GoldDivider extends StatelessWidget {
  const _GoldDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, MPPColors.gold, Colors.transparent],
        ),
      ),
    );
  }
}

// ─── About Party Card ─────────────────────────────────────────
class _AboutPartyCard extends StatelessWidget {
  const _AboutPartyCard();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _SectionHeader(title: 'مکمل پاکستان پارٹی', icon: Icons.account_balance_rounded),
          const _GoldDivider(),
          Text(
            'مکمل پاکستان پارٹی ایک مثبت، باوقار اور نظریاتی سیاسی جماعت ہے جس کا مقصد پاکستان کو ترقی، اتحاد، خودمختاری اور معاشی استحکام کی راہ پر گامزن کرنا ہے۔ جماعت نوجوانوں کو بااختیار بنانے، کاروباری مواقع پیدا کرنے اور ملک میں مثبت سیاست کے فروغ پر یقین رکھتی ہے۔',
            style: MPPTextStyles.bodyUrdu(context),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}

// ─── Youth Business Card ──────────────────────────────────────
class _YouthBusinessCard extends StatelessWidget {
  const _YouthBusinessCard();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _SectionHeader(title: 'نوجوانوں کے لیے کاروباری انقلاب', icon: Icons.rocket_launch_rounded),
          const _GoldDivider(),
          Text(
            'ہماری جماعت پاکستان بھر کے ایسے نوجوانوں کو اکٹھا کرنا چاہتی ہے جو کاروبار کرنے کا جذبہ رکھتے ہیں مگر وسائل یا رہنمائی کی کمی کا شکار ہیں۔ ہم چاہتے ہیں کہ نوجوان اجتماعی طور پر کاروبار شروع کریں جہاں ہر شریک فرد کو برابر کا حصہ دیا جائے۔ تجربہ کار کاروباری شخصیات رہنمائی فراہم کریں تاکہ ایک مضبوط اور پائیدار بزنس ماڈل قائم کیا جا سکے۔',
            style: MPPTextStyles.bodyUrdu(context),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 16),

          // Stat chips
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: const [
              _StatChip(label: 'برابری', icon: Icons.balance),
              _StatChip(label: 'رہنمائی', icon: Icons.school_rounded),
              _StatChip(label: 'اجتماعی کاروبار', icon: Icons.groups_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: MPPColors.emeraldLight.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
        color: MPPColors.emerald.withOpacity(0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: MPPTextStyles.valueLabel(context).copyWith(fontSize: 12), textDirection: TextDirection.rtl),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: MPPColors.emeraldGlow),
        ],
      ),
    );
  }
}

// ─── Chairman Message Card ────────────────────────────────────
class _ChairmanMessageCard extends StatelessWidget {
  const _ChairmanMessageCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MPPColors.emerald.withOpacity(0.35),
            MPPColors.deepForest.withOpacity(0.5),
          ],
        ),
        border: Border.all(color: MPPColors.gold.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(color: MPPColors.emerald.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          // Decorative quote mark
          Positioned(
            top: 12,
            left: 16,
            child: Text(
              '"',
              style: GoogleFonts.playfairDisplay(
                fontSize: 80,
                color: MPPColors.gold.withOpacity(0.15),
                height: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const _SectionHeader(title: 'چیئرمین کا پیغام', icon: Icons.format_quote_rounded),
                const _GoldDivider(),
                Text(
                  'چیئرمین محمد عبدالمتین ہاشمی کا ماننا ہے کہ سیاست کا مقصد عوامی خدمت، قومی اتحاد اور مثبت تبدیلی ہونا چاہیے۔ مکمل پاکستان پارٹی کسی بھی صورت عوامی جذبات کو بھڑکا کر یا قوم کو تقسیم کر کے سیاست نہیں کرنا چاہتی۔ ہماری سیاست اخلاقیات، برداشت، اتحاد اور پاکستان کی حقیقی ترقی پر مبنی ہے۔',
                  style: MPPTextStyles.bodyUrdu(context).copyWith(color: MPPColors.textPrimary),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),
                // Attribution
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('محمد عبدالمتین ہاشمی',
                            style: GoogleFonts.notoNaskhArabic(
                                color: MPPColors.goldLight, fontWeight: FontWeight.w700, fontSize: 14),
                            textDirection: TextDirection.rtl),
                        Text('چیئرمین',
                            style: GoogleFonts.notoNaskhArabic(
                                color: MPPColors.textSecondary, fontSize: 12),
                            textDirection: TextDirection.rtl),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: MPPColors.gold, width: 1.5),
                      ),
                      child: const Icon(Icons.person, color: MPPColors.gold, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Core Values Section ──────────────────────────────────────
class _CoreValuesSection extends StatelessWidget {
  const _CoreValuesSection();

  static const _values = [
    _ValueData(label: 'اتحاد', sublabel: 'Unity', icon: Icons.link_rounded, color: Color(0xFF27AE60)),
    _ValueData(label: 'اخلاقیات', sublabel: 'Ethics', icon: Icons.balance_rounded, color: Color(0xFFD4AF37)),
    _ValueData(label: 'نوجوان', sublabel: 'Youth', icon: Icons.emoji_people_rounded, color: Color(0xFF2980B9)),
    _ValueData(label: 'معاشی ترقی', sublabel: 'Economy', icon: Icons.trending_up_rounded, color: Color(0xFF8E44AD)),
    _ValueData(label: 'مثبت سیاست', sublabel: 'Positive', icon: Icons.thumb_up_rounded, color: Color(0xFFE67E22)),
    _ValueData(label: 'قومی استحکام', sublabel: 'Stability', icon: Icons.shield_rounded, color: Color(0xFF1ABC9C)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [MPPColors.emerald, MPPColors.emeraldLight],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.grid_view_rounded, color: MPPColors.snowWhite, size: 18),
                ),
                const SizedBox(width: 12),
                Text('ہماری بنیادی اقدار',
                    style: MPPTextStyles.sectionTitle(context),
                    textDirection: TextDirection.rtl),
              ],
            ),
          ),

          // Values grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _values.length,
            itemBuilder: (ctx, i) => _ValueCard(data: _values[i]),
          ),
        ],
      ),
    );
  }
}

class _ValueData {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  const _ValueData({required this.label, required this.sublabel, required this.icon, required this.color});
}

class _ValueCard extends StatefulWidget {
  final _ValueData data;
  const _ValueCard({super.key, required this.data});
  @override
  State<_ValueCard> createState() => _ValueCardState();
}

class _ValueCardState extends State<_ValueCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { setState(() => _pressed = true); _ctrl.forward(); },
      onTapUp: (_) { setState(() => _pressed = false); _ctrl.reverse(); },
      onTapCancel: () { setState(() => _pressed = false); _ctrl.reverse(); },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (ctx, child) => Transform.scale(scale: _scaleAnim.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.data.color.withOpacity(_pressed ? 0.30 : 0.15),
                MPPColors.glassWhite,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? widget.data.color.withOpacity(0.8)
                  : widget.data.color.withOpacity(0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.data.color.withOpacity(_pressed ? 0.4 : 0.15),
                blurRadius: _pressed ? 18 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.data.color.withOpacity(0.2),
                  border: Border.all(color: widget.data.color.withOpacity(0.5), width: 1),
                ),
                child: Icon(widget.data.icon, color: widget.data.color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                widget.data.label,
                style: MPPTextStyles.valueLabel(context),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                maxLines: 2,
              ),
              const SizedBox(height: 2),
              Text(
                widget.data.sublabel,
                style: GoogleFonts.lato(
                  fontSize: 10,
                  color: widget.data.color,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Footer Quote ─────────────────────────────────────────────
class _FooterQuote extends StatelessWidget {
  const _FooterQuote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MPPColors.emerald.withOpacity(0.4),
            MPPColors.deepForest.withOpacity(0.6),
            MPPColors.emerald.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: MPPColors.gold.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: MPPColors.emerald.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Stars row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
                  (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(Icons.star, color: MPPColors.gold, size: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // English quote
          Text(
            'Together We Build\na Complete Pakistan',
            style: MPPTextStyles.footerEn(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Gold separator
          Container(
            width: 60,
            height: 2,
            decoration: const BoxDecoration(
              gradient: MPPColors.goldAccent,
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),

          // Urdu quote
          Text(
            'آئیں مل کر ایک مکمل پاکستان تعمیر کریں',
            style: MPPTextStyles.footerUr(context),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 20),

          // Party name badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: MPPColors.glassWhite,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: MPPColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flag_rounded, color: MPPColors.emeraldGlow, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Mukammal Pakistan Party',
                  style: GoogleFonts.lato(
                    color: MPPColors.snowWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}