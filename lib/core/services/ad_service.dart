import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Barcha AdMob reklamalarini boshqaruvchi markaziy xizmat.
///
/// Premium tizim: foydalanuvchi kuniga 3 ta rewarded video ko'rsa,
/// 24 soat davomida hech qanday reklama ko'rsatilmaydi.
class AdService {
  AdService._();
  static final instance = AdService._();

  // ============================================================
  // AdMob reklama ID lari (production)
  // ============================================================
  static String get bannerAdUnitId =>
      'ca-app-pub-2977939261747724/9868044550';

  static String get interstitialAdUnitId =>
      'ca-app-pub-2977939261747724/8528311645';

  static String get rewardedAdUnitId =>
      'ca-app-pub-2977939261747724/5902148301';

  static String get nativeAdUnitId =>
      'ca-app-pub-2977939261747724/4257894146';

  // ============================================================
  // Premium tizim — 3 ta rewarded = 24 soat reklamasiz
  // ============================================================
  static const _premiumActivatedAtKey = 'premium_activated_at';
  static const _premiumDuration = Duration(hours: 24);

  /// Premium faolmi tekshirish (24 soat ichida 3 ta rewarded ko'rilgan)
  Future<bool> isPremiumActive() async {
    final prefs = await SharedPreferences.getInstance();
    final activatedAt = prefs.getInt(_premiumActivatedAtKey);
    if (activatedAt == null) return false;

    final activatedTime = DateTime.fromMillisecondsSinceEpoch(activatedAt);
    final now = DateTime.now();
    return now.difference(activatedTime) < _premiumDuration;
  }

  /// Premium tugash vaqtini olish (null agar faol emas bo'lsa)
  Future<DateTime?> getPremiumExpiresAt() async {
    final prefs = await SharedPreferences.getInstance();
    final activatedAt = prefs.getInt(_premiumActivatedAtKey);
    if (activatedAt == null) return null;

    final activatedTime = DateTime.fromMillisecondsSinceEpoch(activatedAt);
    final expiresAt = activatedTime.add(_premiumDuration);
    if (DateTime.now().isAfter(expiresAt)) return null;
    return expiresAt;
  }

  /// Premiumni faollashtirish
  Future<void> _activatePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _premiumActivatedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ============================================================
  // Interstitial reklama — har 3-chi ochilishda (premium bo'lmasa)
  // ============================================================
  InterstitialAd? _interstitialAd;
  int _appOpenCount = 0;
  static const _appOpenCountKey = 'app_open_count';

  /// MobileAds ni ishga tushirish
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  /// Interstitial reklamani yuklash
  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial yuklashda xatolik: ${error.message}');
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Ilova ochilganda interstitial ko'rsatish (har 3-chi safar, premium bo'lmasa)
  Future<void> showInterstitialIfReady() async {
    // Premium faol bo'lsa — reklama ko'rsatilmaydi
    if (await isPremiumActive()) return;

    final prefs = await SharedPreferences.getInstance();
    _appOpenCount = (prefs.getInt(_appOpenCountKey) ?? 0) + 1;
    await prefs.setInt(_appOpenCountKey, _appOpenCount);

    if (_appOpenCount % 3 == 0 && _interstitialAd != null) {
      _interstitialAd!.show();
    }
  }

  // ============================================================
  // Rewarded reklama — kuniga 3 ta, 3-chisi tugaganda premium faollashadi
  // ============================================================
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;
  static const _rewardedDateKey = 'rewarded_date';
  static const _rewardedCountKey = 'rewarded_count';
  static const maxDailyRewarded = 3;

  /// Rewarded reklamani yuklash
  void loadRewardedAd() {
    if (_isRewardedAdLoading) return;
    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded yuklashda xatolik: ${error.message}');
          _isRewardedAdLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Bugungi ko'rilgan rewarded reklama sonini olish
  Future<int> getTodayRewardedCount() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_rewardedDateKey) ?? '';
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (savedDate != today) {
      await prefs.setString(_rewardedDateKey, today);
      await prefs.setInt(_rewardedCountKey, 0);
      return 0;
    }
    return prefs.getInt(_rewardedCountKey) ?? 0;
  }

  /// Rewarded reklamani ko'rsatish.
  /// 3-chi video tugaganda avtomatik premium faollashadi.
  Future<bool> showRewardedAd({
    required void Function(AdWithoutView ad, RewardItem reward) onUserEarnedReward,
  }) async {
    final count = await getTodayRewardedCount();
    if (count >= maxDailyRewarded) return false;
    if (_rewardedAd == null) return false;

    _rewardedAd!.show(onUserEarnedReward: (ad, reward) async {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final newCount = count + 1;
      await prefs.setString(_rewardedDateKey, today);
      await prefs.setInt(_rewardedCountKey, newCount);

      // 3-chi rewarded ko'rilganda — 24 soat premium faollashadi
      if (newCount >= maxDailyRewarded) {
        await _activatePremium();
      }

      onUserEarnedReward(ad, reward);
    });
    return true;
  }

  /// Barcha resurslarni tozalash
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
