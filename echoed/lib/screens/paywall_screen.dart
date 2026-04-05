import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../core/constants.dart';
import '../providers/subscription_provider.dart';
import '../widgets/waveform_painter.dart';

/// Paywall / upgrade screen — shows premium features and RevenueCat packages.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key, required this.triggerSource});
  final String triggerSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offeringsAsync = ref.watch(offeringsProvider);
    final purchaseState = ref.watch(purchaseNotifierProvider);

    // Navigate away on successful purchase
    ref.listen<AsyncValue<bool?>>(purchaseNotifierProvider, (_, next) {
      if (next.valueOrNull == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Echoed Premium!'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.pop();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
                  ),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Decorative waveforms
                    SizedBox(
                      height: 80,
                      child: Stack(
                        children: List.generate(5, (i) => Positioned.fill(
                          child: CustomPaint(
                            painter: WaveformPainter(
                              targetHz: 300.0 + i * 300,
                              animationValue: 1.0,
                              targetColor: AppColors.primary.withOpacity(0.1 + i * 0.05),
                            ),
                          ),
                        )),
                      ),
                    ).animate().fadeIn(),

                    const SizedBox(height: AppSpacing.md),

                    Text(
                      'Echoed Premium',
                      style: AppTextStyles.headingLarge,
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 100.ms),

                    const SizedBox(height: 8),

                    Text(
                      'Sharpen your ear. No limits.',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 150.ms),

                    const SizedBox(height: AppSpacing.xl),

                    // Feature list
                    ..._features.asMap().entries.map((e) => _FeatureRow(
                      icon: e.value.$1,
                      label: e.value.$2,
                      delay: Duration(milliseconds: 200 + 50 * e.key),
                    )),

                    const SizedBox(height: AppSpacing.xl),

                    // Packages
                    offeringsAsync.when(
                      data: (packages) => _PackagesSection(
                        packages: packages,
                        purchaseState: purchaseState,
                        onPurchase: (pkg) => ref.read(purchaseNotifierProvider.notifier).purchase(pkg),
                      ),
                      loading: () => const CircularProgressIndicator(color: AppColors.primary),
                      error: (_, __) => Text(
                        'Unable to load pricing. Try again.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ).animate().fadeIn(delay: 500.ms),

                    const SizedBox(height: AppSpacing.md),

                    // Restore
                    TextButton(
                      onPressed: purchaseState.isLoading
                          ? null
                          : () => ref.read(purchaseNotifierProvider.notifier).restore(),
                      child: const Text('Restore Purchases'),
                    ),

                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Subscriptions renew automatically. Cancel anytime in your device settings.',
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<(IconData, String)> _features = [
    (Icons.all_inclusive_rounded, 'Unlimited solo games every day'),
    (Icons.bar_chart_rounded, 'Score history graphs and stats'),
    (Icons.wifi_off_rounded, 'Offline daily challenges'),
    (Icons.group_rounded, 'Private multiplayer groups'),
    (Icons.library_music_rounded, 'Seasonal tone packs'),
    (Icons.block_rounded, 'No advertisements'),
  ];
}

// ── Feature row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label, required this.delay});
  final IconData icon;
  final String label;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Text(label, style: AppTextStyles.bodyLarge),
        ],
      ),
    ).animate().fadeIn(delay: delay, duration: 250.ms).slideX(begin: 0.05);
  }
}

// ── Packages section ──────────────────────────────────────────────────────────

class _PackagesSection extends StatefulWidget {
  const _PackagesSection({
    required this.packages,
    required this.purchaseState,
    required this.onPurchase,
  });

  final List<Package> packages;
  final AsyncValue<bool?> purchaseState;
  final void Function(Package) onPurchase;

  @override
  State<_PackagesSection> createState() => _PackagesSectionState();
}

class _PackagesSectionState extends State<_PackagesSection> {
  int _selectedIndex = 1; // default to annual

  @override
  Widget build(BuildContext context) {
    if (widget.packages.isEmpty) {
      // Fallback pricing display (no RevenueCat offerings loaded)
      return Column(
        children: [
          _PackageCard(
            title: 'Monthly',
            price: '\$3.99/month',
            isSelected: _selectedIndex == 0,
            badge: null,
            onTap: () => setState(() => _selectedIndex = 0),
          ),
          const SizedBox(height: 8),
          _PackageCard(
            title: 'Annual',
            price: '\$29.99/year',
            isSelected: _selectedIndex == 1,
            badge: 'SAVE 37%',
            onTap: () => setState(() => _selectedIndex = 1),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: null,
              child: const Text('Start 7-Day Free Trial'),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        ...widget.packages.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PackageCard(
            title: e.value.packageType == PackageType.monthly ? 'Monthly' : 'Annual',
            price: e.value.storeProduct.priceString,
            isSelected: _selectedIndex == e.key,
            badge: e.value.packageType == PackageType.annual ? 'BEST VALUE' : null,
            onTap: () => setState(() => _selectedIndex = e.key),
          ),
        )),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.purchaseState.isLoading
                ? null
                : () {
                    if (_selectedIndex < widget.packages.length) {
                      widget.onPurchase(widget.packages[_selectedIndex]);
                    }
                  },
            child: widget.purchaseState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                  )
                : const Text('Start 7-Day Free Trial'),
          ),
        ),
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.title,
    required this.price,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String price;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: AppColors.textPrimary, size: 12)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: AppTextStyles.bodyLarge),
            ),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge!, style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent, fontSize: 9)),
              ),
            Text(
              price,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
