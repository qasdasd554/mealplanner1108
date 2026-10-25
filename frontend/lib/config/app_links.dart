import '../services/account_market.dart';

/// Immutable destinations; resolving a market never changes another account.
class AppDocumentDestinations {
  final String website;
  final String contactEmail;

  const AppDocumentDestinations({
    required this.website,
    required this.contactEmail,
  });

  String get terms => '$website/terms-of-use.html';
  String get privacy => '$website/privacy-policy.html';
  String get accountDeletion => '$website/delete-account.html';
  String get support => '$website/support.html';
  Uri get contact => Uri(scheme: 'mailto', path: contactEmail);
}

/// Existing PL URLs remain compatible. UK root pages verified 24 October 2026;
/// `/en/` is not a published path. No network lookup is needed to render links.
abstract final class AppLinks {
  static const website = 'https://mealplannerpolska.pl';
  static const terms = '$website/terms-of-use.html';
  static const privacy = '$website/privacy-policy.html';
  static const accountDeletion = '$website/delete-account.html';
  static const support = '$website/support.html';
  static const contactEmail = 'kontakt@mealplannerpolska.pl';
  static final contact = Uri(scheme: 'mailto', path: contactEmail);

  static const _polish = AppDocumentDestinations(
    website: website,
    contactEmail: contactEmail,
  );
  static const _british = AppDocumentDestinations(
    website: 'https://mealplannerworld.com',
    contactEmail: 'support@mealplannerworld.com',
  );

  /// Pass the registered market (or the root app locale derived from it),
  /// not a new phone-region lookup for an already authenticated account.
  static AppDocumentDestinations forCountry(String? country) =>
      normalizeAccountCountry(country) == 'GB' ? _british : _polish;
}
