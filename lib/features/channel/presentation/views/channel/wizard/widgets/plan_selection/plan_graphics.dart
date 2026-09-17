import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 3D Shield graphic representing the Standard Channel plan.
class Standard3DGraphic extends StatelessWidget {
  const Standard3DGraphic({required this.isDesktop, super.key});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final scale = isDesktop ? 0.75 : 1.0;
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        height: isDesktop ? 75 : 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.35),
                    const Color(0xFF7C3AED).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              child: Container(
                width: 100,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(
                    Radius.elliptical(100, 28),
                  ),
                  color: const Color(0xFF1E1B4B),
                  border: Border.all(
                    color: const Color(0xFF4C1D95),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 22,
              child: Container(
                width: 80,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(
                    Radius.elliptical(80, 22),
                  ),
                  color: const Color(0xFF311042),
                  border: Border.all(
                    color: const Color(0xFF7C3AED),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF4C1D95),
                      Color(0xFF1E1B4B),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFFA855F7), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.5),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3D Rocket graphic representing the Custom Channel plan.
class CustomRocket3DGraphic extends StatelessWidget {
  const CustomRocket3DGraphic({required this.isDesktop, super.key});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final scale = isDesktop ? 0.75 : 1.0;
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        height: isDesktop ? 75 : 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withOpacity(0.4),
                    const Color(0xFF6366F1).withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              child: Container(
                width: 76,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFA855F7).withOpacity(0.6),
                      const Color(0xFF4C1D95).withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF6D28D9),
                      Color(0xFF311042),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFFC084FC), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA855F7).withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.rocket_launch,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 24,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4C1D95),
                  border: Border.all(color: const Color(0xFFA855F7)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
            Positioned(
              right: 14,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF5B21B6),
                  border: Border.all(color: const Color(0xFFC084FC)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.attach_money,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
            Positioned(
              right: 18,
              top: 18,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF311042),
                  border: Border.all(color: const Color(0xFFA855F7)),
                ),
                child: const Icon(
                  Icons.bar_chart,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3D Perspective dashboard graphic representation.
class Dashboard3DGraphic extends StatelessWidget {
  const Dashboard3DGraphic({required this.isDesktop, super.key});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final scale = isDesktop ? 0.75 : 1.0;
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        height: isDesktop ? 110 : 180,
        width: isDesktop ? 160 : 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 180,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C3AED).withOpacity(0.35),
                    const Color(0xFF4C1D95).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(-0.15)
                ..rotateX(0.1),
              alignment: FractionalOffset.center,
              child: Container(
                width: 170,
                height: 115,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161528),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF7C3AED),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 12,
                          height: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: const Color(0xFF4C1D95),
                          ),
                        ),
                        Container(
                          width: 12,
                          height: 35,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: const Color(0xFF6D28D9),
                          ),
                        ),
                        Container(
                          width: 12,
                          height: 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        Container(
                          width: 12,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: const Color(0xFFA855F7),
                          ),
                        ),
                        Container(
                          width: 12,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: const Color(0xFFC084FC),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.attach_money,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 16,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
            Positioned(
              left: 4,
              top: 40,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEC4899),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC4899).withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Secondary analytics and growth dashboard graphic.
class DashboardGraphic extends StatelessWidget {
  const DashboardGraphic({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.12),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, color: Colors.white, size: 36),
                  SizedBox(width: 12),
                  Icon(Icons.trending_up, color: Colors.white, size: 40),
                  SizedBox(width: 12),
                  Icon(
                    Icons.monetization_on_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'TruthWorld Analytics & Monetization',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Unlock 100% Revenue Share & Priority Growth',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
