/// Public documents verified on mealplannerpolska.pl, 14 October 2026.
abstract final class AppLinks {
  static const website = 'https://mealplannerpolska.pl';
  static const terms = '$website/terms-of-use.html';
  static const privacy = '$website/privacy-policy.html';
  static const accountDeletion = '$website/delete-account.html';
  static const support = '$website/support.html';
  static const contactEmail = 'kontakt@mealplannerpolska.pl';
  static final contact = Uri(scheme: 'mailto', path: contactEmail);
}
