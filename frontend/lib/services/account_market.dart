/// Country identifiers are persisted on account creation, not inferred again
/// when an existing user logs in or travels. Unsupported/missing device regions
/// keep the existing Polish market; `UK` is accepted as a compatibility alias.
String normalizeAccountCountry(String? region) {
  final country = region?.trim().toUpperCase();
  return country == 'GB' || country == 'UK' ? 'GB' : 'PL';
}

/// Shared by email, Google and Apple account-creation requests. The backend is
/// authoritative: it ignores this hint when the account already exists.
Map<String, String> registrationMarketFields(String? deviceRegion) => {
  'device_region': normalizeAccountCountry(deviceRegion),
};
