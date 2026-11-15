/// "reload", "reloaded", "top up", "top-up", "topped up" or "topup" as words.
final _topUp = RegExp(
  r'\b(?:re-?load(?:ed|ing)?|top(?:ped)?[ -]?up)\b',
  caseSensitive: false,
);

/// True when [text] tells of a wallet top-up, for example "RM20.00 has been reloaded to your
/// Touch 'n Go eWallet balance". A top-up moves the owner's own money, so it is usually not spending.
bool looksLikeTopUp(String text) => _topUp.hasMatch(text);
