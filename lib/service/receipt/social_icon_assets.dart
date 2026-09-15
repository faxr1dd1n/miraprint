/// `SocialLink.icon`dan `assets/social_media/`dagi haqiqiy faylga
/// o'tkazish uchun umumiy xarita — chek canvas-renderer (chop etish) va
/// ilova ichidagi preview widget ikkalasi ham shundan foydalanadi, shunda
/// ikkalasida bir xil ikonka ko'rinadi.
const socialIconAssets = {
  'facebook': 'facebook_square.svg',
  'gmail': 'gmail_outlined.svg',
  'instagram': 'instagram.svg',
  'linkedin': 'linkedin_square.svg',
  'telegram': 'telegram.svg',
  'twitter': 'twitter.svg',
};

/// Ro'yxatda yo'q nom kelsa (masalan `youtube`) shu ishlatiladi.
const fallbackSocialIconFile = 'telegram.svg';

String socialIconAssetPath(String icon) {
  final file = socialIconAssets[icon.toLowerCase()] ?? fallbackSocialIconFile;
  return 'assets/social_media/$file';
}
