/// Information regarding a country supported by Cashfree Payments
class CashfreeCountryInfo {
  final String code; // ISO 2-letter country code
  final String name; // Full country name
  final String currency; // Primary currency ISO code
  final String currencySymbol; // Display symbol
  final bool isRestricted; // Whether restricted by compliance/sanctions

  const CashfreeCountryInfo({
    required this.code,
    required this.name,
    required this.currency,
    required this.currencySymbol,
    this.isRestricted = false,
  });

  bool get isSupported => !isRestricted;

  /// Flag emoji representing the country (e.g. 🇮🇳, 🇺🇸, 🇬🇧)
  String get flagEmoji => CashfreeCountrySupport.countryCodeToEmoji(code);
}

/// Comprehensive directory of all countries and currencies provided by
/// Cashfree's International Payment Gateway (200+ countries, 140+ currencies).
class CashfreeCountrySupport {
  CashfreeCountrySupport._();

  /// Cashfree strictly restricts 9 countries in compliance with international
  /// FATF, OFAC, and Indian banking regulatory sanctions.
  static const Set<String> restrictedCountryCodes = {
    'AF', // Afghanistan
    'BY', // Belarus
    'CU', // Cuba
    'IR', // Iran
    'IQ', // Iraq
    'PK', // Pakistan
    'RU', // Russia
    'SD', // Sudan
    'SY', // Syria
  };

  /// Primary 140+ currencies supported by Cashfree International Payment Gateway.
  static const Set<String> supportedCurrencies = {
    'INR', 'USD', 'EUR', 'GBP', 'AUD', 'CAD', 'SGD', 'AED', 'SAR', 'QAR',
    'JPY', 'CHF', 'NZD', 'ZAR', 'BRL', 'MYR', 'THB', 'SEK', 'NOK', 'DKK',
    'HKD', 'PLN', 'MXN', 'PHP', 'IDR', 'VND', 'KRW', 'KWD', 'BHD', 'OMR',
    'ILS', 'CLP', 'COP', 'PEN', 'ARS', 'EGP', 'NGN', 'KES', 'GHS', 'TRY',
    'CZK', 'HUF', 'RON', 'BGN', 'HRK', 'ISK', 'TWD', 'BDT', 'LKR', 'NPR',
    'MAD', 'DZD', 'TND', 'JOD', 'LBP', 'BAM', 'RSD', 'UAH', 'KZT', 'AZN',
    'GEL', 'AMD', 'MNT', 'UZS', 'BOB', 'CRC', 'DOP', 'GTQ', 'HNL', 'NIO',
    'PAB', 'PYG', 'UYU', 'TTD', 'JMD', 'BBD', 'BSD', 'BZD', 'XCD', 'FJD',
    'PGK', 'WST', 'TOP', 'VUV', 'SBD', 'MUR', 'SCR', 'BWP', 'NAD', 'SZL',
    'LSL', 'MZN', 'AOA', 'ZMW', 'RWF', 'UGX', 'TZS', 'ETB', 'DJF', 'MGA',
    'MWK', 'GMD', 'SLL', 'LRD', 'GNF', 'CVE', 'STN', 'XOF', 'XAF', 'CDF',
    'KMF', 'BIF', 'BND', 'KHR', 'LAK', 'MMK', 'MOP', 'MDL', 'ALL', 'MKD',
    'BMD', 'KYD', 'GIP', 'FKP', 'SHP', 'AWG', 'ANG', 'SRD', 'GYD', 'HTG',
  };

  /// Currencies that have zero decimal places in Cashfree API (e.g. 100 JPY, not 100.00 JPY)
  static const Set<String> zeroDecimalCurrencies = {
    'JPY', 'KRW', 'VND', 'IDR', 'CLP', 'PYG', 'UGX', 'RWF', 'BIF', 'DJF',
    'GNF', 'KMF', 'MGA', 'VUV', 'XAF', 'XOF',
  };

  /// Currencies with 3 decimal places (Middle East dinars/rials)
  static const Set<String> threeDecimalCurrencies = {
    'BHD', 'KWD', 'OMR', 'JOD', 'TND',
  };

  /// Registry mapping ISO 2-letter country codes to their information
  static const Map<String, CashfreeCountryInfo> _countryRegistry = {
    // Domestic Primary
    'IN': CashfreeCountryInfo(code: 'IN', name: 'India', currency: 'INR', currencySymbol: '₹'),

    // Major Global & North America
    'US': CashfreeCountryInfo(code: 'US', name: 'United States', currency: 'USD', currencySymbol: r'$'),
    'CA': CashfreeCountryInfo(code: 'CA', name: 'Canada', currency: 'CAD', currencySymbol: r'CA$'),
    'MX': CashfreeCountryInfo(code: 'MX', name: 'Mexico', currency: 'MXN', currencySymbol: r'MX$'),

    // Europe
    'GB': CashfreeCountryInfo(code: 'GB', name: 'United Kingdom', currency: 'GBP', currencySymbol: '£'),
    'DE': CashfreeCountryInfo(code: 'DE', name: 'Germany', currency: 'EUR', currencySymbol: '€'),
    'FR': CashfreeCountryInfo(code: 'FR', name: 'France', currency: 'EUR', currencySymbol: '€'),
    'IT': CashfreeCountryInfo(code: 'IT', name: 'Italy', currency: 'EUR', currencySymbol: '€'),
    'ES': CashfreeCountryInfo(code: 'ES', name: 'Spain', currency: 'EUR', currencySymbol: '€'),
    'NL': CashfreeCountryInfo(code: 'NL', name: 'Netherlands', currency: 'EUR', currencySymbol: '€'),
    'BE': CashfreeCountryInfo(code: 'BE', name: 'Belgium', currency: 'EUR', currencySymbol: '€'),
    'AT': CashfreeCountryInfo(code: 'AT', name: 'Austria', currency: 'EUR', currencySymbol: '€'),
    'CH': CashfreeCountryInfo(code: 'CH', name: 'Switzerland', currency: 'CHF', currencySymbol: 'CHF'),
    'SE': CashfreeCountryInfo(code: 'SE', name: 'Sweden', currency: 'SEK', currencySymbol: 'kr'),
    'NO': CashfreeCountryInfo(code: 'NO', name: 'Norway', currency: 'NOK', currencySymbol: 'kr'),
    'DK': CashfreeCountryInfo(code: 'DK', name: 'Denmark', currency: 'DKK', currencySymbol: 'kr.'),
    'FI': CashfreeCountryInfo(code: 'FI', name: 'Finland', currency: 'EUR', currencySymbol: '€'),
    'IE': CashfreeCountryInfo(code: 'IE', name: 'Ireland', currency: 'EUR', currencySymbol: '€'),
    'PT': CashfreeCountryInfo(code: 'PT', name: 'Portugal', currency: 'EUR', currencySymbol: '€'),
    'PL': CashfreeCountryInfo(code: 'PL', name: 'Poland', currency: 'PLN', currencySymbol: 'zł'),
    'CZ': CashfreeCountryInfo(code: 'CZ', name: 'Czech Republic', currency: 'CZK', currencySymbol: 'Kč'),
    'GR': CashfreeCountryInfo(code: 'GR', name: 'Greece', currency: 'EUR', currencySymbol: '€'),
    'RO': CashfreeCountryInfo(code: 'RO', name: 'Romania', currency: 'RON', currencySymbol: 'lei'),
    'HU': CashfreeCountryInfo(code: 'HU', name: 'Hungary', currency: 'HUF', currencySymbol: 'Ft'),

    // Middle East & North Africa
    'AE': CashfreeCountryInfo(code: 'AE', name: 'United Arab Emirates', currency: 'AED', currencySymbol: 'AED'),
    'SA': CashfreeCountryInfo(code: 'SA', name: 'Saudi Arabia', currency: 'SAR', currencySymbol: 'SAR'),
    'QA': CashfreeCountryInfo(code: 'QA', name: 'Qatar', currency: 'QAR', currencySymbol: 'QAR'),
    'KW': CashfreeCountryInfo(code: 'KW', name: 'Kuwait', currency: 'KWD', currencySymbol: 'KWD'),
    'BH': CashfreeCountryInfo(code: 'BH', name: 'Bahrain', currency: 'BHD', currencySymbol: 'BHD'),
    'OM': CashfreeCountryInfo(code: 'OM', name: 'Oman', currency: 'OMR', currencySymbol: 'OMR'),
    'IL': CashfreeCountryInfo(code: 'IL', name: 'Israel', currency: 'ILS', currencySymbol: '₪'),
    'TR': CashfreeCountryInfo(code: 'TR', name: 'Turkey', currency: 'TRY', currencySymbol: '₺'),
    'EG': CashfreeCountryInfo(code: 'EG', name: 'Egypt', currency: 'EGP', currencySymbol: 'E£'),
    'MA': CashfreeCountryInfo(code: 'MA', name: 'Morocco', currency: 'MAD', currencySymbol: 'MAD'),

    // Asia-Pacific
    'AU': CashfreeCountryInfo(code: 'AU', name: 'Australia', currency: 'AUD', currencySymbol: r'A$'),
    'NZ': CashfreeCountryInfo(code: 'NZ', name: 'New Zealand', currency: 'NZD', currencySymbol: r'NZ$'),
    'SG': CashfreeCountryInfo(code: 'SG', name: 'Singapore', currency: 'SGD', currencySymbol: r'S$'),
    'MY': CashfreeCountryInfo(code: 'MY', name: 'Malaysia', currency: 'MYR', currencySymbol: 'RM'),
    'JP': CashfreeCountryInfo(code: 'JP', name: 'Japan', currency: 'JPY', currencySymbol: '¥'),
    'KR': CashfreeCountryInfo(code: 'KR', name: 'South Korea', currency: 'KRW', currencySymbol: '₩'),
    'HK': CashfreeCountryInfo(code: 'HK', name: 'Hong Kong', currency: 'HKD', currencySymbol: r'HK$'),
    'TW': CashfreeCountryInfo(code: 'TW', name: 'Taiwan', currency: 'TWD', currencySymbol: r'NT$'),
    'TH': CashfreeCountryInfo(code: 'TH', name: 'Thailand', currency: 'THB', currencySymbol: '฿'),
    'ID': CashfreeCountryInfo(code: 'ID', name: 'Indonesia', currency: 'IDR', currencySymbol: 'Rp'),
    'PH': CashfreeCountryInfo(code: 'PH', name: 'Philippines', currency: 'PHP', currencySymbol: '₱'),
    'VN': CashfreeCountryInfo(code: 'VN', name: 'Vietnam', currency: 'VND', currencySymbol: '₫'),
    'BD': CashfreeCountryInfo(code: 'BD', name: 'Bangladesh', currency: 'BDT', currencySymbol: '৳'),
    'LK': CashfreeCountryInfo(code: 'LK', name: 'Sri Lanka', currency: 'LKR', currencySymbol: 'Rs'),
    'NP': CashfreeCountryInfo(code: 'NP', name: 'Nepal', currency: 'NPR', currencySymbol: 'Rs'),

    // Latin America
    'BR': CashfreeCountryInfo(code: 'BR', name: 'Brazil', currency: 'BRL', currencySymbol: r'R$'),
    'AR': CashfreeCountryInfo(code: 'AR', name: 'Argentina', currency: 'ARS', currencySymbol: r'$'),
    'CL': CashfreeCountryInfo(code: 'CL', name: 'Chile', currency: 'CLP', currencySymbol: r'CLP$'),
    'CO': CashfreeCountryInfo(code: 'CO', name: 'Colombia', currency: 'COP', currencySymbol: r'COL$'),
    'PE': CashfreeCountryInfo(code: 'PE', name: 'Peru', currency: 'PEN', currencySymbol: 'S/'),

    // Africa
    'ZA': CashfreeCountryInfo(code: 'ZA', name: 'South Africa', currency: 'ZAR', currencySymbol: 'R'),
    'NG': CashfreeCountryInfo(code: 'NG', name: 'Nigeria', currency: 'NGN', currencySymbol: '₦'),
    'KE': CashfreeCountryInfo(code: 'KE', name: 'Kenya', currency: 'KES', currencySymbol: 'KSh'),
    'GH': CashfreeCountryInfo(code: 'GH', name: 'Ghana', currency: 'GHS', currencySymbol: 'GH₵'),

    // Restricted Countries (for compliance detection)
    'AF': CashfreeCountryInfo(code: 'AF', name: 'Afghanistan', currency: 'AFN', currencySymbol: 'Af', isRestricted: true),
    'BY': CashfreeCountryInfo(code: 'BY', name: 'Belarus', currency: 'BYN', currencySymbol: 'Br', isRestricted: true),
    'CU': CashfreeCountryInfo(code: 'CU', name: 'Cuba', currency: 'CUP', currencySymbol: r'$', isRestricted: true),
    'IR': CashfreeCountryInfo(code: 'IR', name: 'Iran', currency: 'IRR', currencySymbol: '﷼', isRestricted: true),
    'IQ': CashfreeCountryInfo(code: 'IQ', name: 'Iraq', currency: 'IQD', currencySymbol: 'ع.د', isRestricted: true),
    'PK': CashfreeCountryInfo(code: 'PK', name: 'Pakistan', currency: 'PKR', currencySymbol: '₨', isRestricted: true),
    'RU': CashfreeCountryInfo(code: 'RU', name: 'Russia', currency: 'RUB', currencySymbol: '₽', isRestricted: true),
    'SD': CashfreeCountryInfo(code: 'SD', name: 'Sudan', currency: 'SDG', currencySymbol: 'ج.س.', isRestricted: true),
    'SY': CashfreeCountryInfo(code: 'SY', name: 'Syria', currency: 'SYP', currencySymbol: '£', isRestricted: true),
  };

  /// Currency symbols map for easy lookups
  static const Map<String, String> _currencySymbols = {
    'INR': '₹',
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'CAD': r'CA$',
    'AUD': r'A$',
    'SGD': r'S$',
    'AED': 'AED',
    'SAR': 'SAR',
    'QAR': 'QAR',
    'JPY': '¥',
    'CHF': 'CHF',
    'NZD': r'NZ$',
    'ZAR': 'R',
    'BRL': r'R$',
    'MYR': 'RM',
    'THB': '฿',
    'SEK': 'kr',
    'NOK': 'kr',
    'DKK': 'kr.',
    'HKD': r'HK$',
    'PLN': 'zł',
    'MXN': r'MX$',
    'PHP': '₱',
    'IDR': 'Rp',
    'VND': '₫',
    'KRW': '₩',
    'KWD': 'KWD',
    'BHD': 'BHD',
    'OMR': 'OMR',
    'ILS': '₪',
    'TRY': '₺',
    'EGP': 'E£',
    'NGN': '₦',
    'KES': 'KSh',
  };

  /// Country name and ISO-3 aliases to standard ISO-2 codes
  static const Map<String, String> _countryAliases = {
    'INDIA': 'IN',
    'IND': 'IN',
    'UNITED STATES': 'US',
    'UNITED STATES OF AMERICA': 'US',
    'USA': 'US',
    'UNITED KINGDOM': 'GB',
    'UK': 'GB',
    'GREAT BRITAIN': 'GB',
    'GBR': 'GB',
    'CANADA': 'CA',
    'CAN': 'CA',
    'AUSTRALIA': 'AU',
    'AUS': 'AU',
    'GERMANY': 'DE',
    'DEU': 'DE',
    'FRANCE': 'FR',
    'FRA': 'FR',
    'CHINA': 'CN',
    'CHN': 'CN',
    'JAPAN': 'JP',
    'JPN': 'JP',
    'SINGAPORE': 'SG',
    'SGP': 'SG',
    'UAE': 'AE',
    'ARE': 'AE',
    'UNITED ARAB EMIRATES': 'AE',
    'SAUDI ARABIA': 'SA',
    'SAU': 'SA',
    'BRAZIL': 'BR',
    'BRA': 'BR',
    'MEXICO': 'MX',
    'MEX': 'MX',
    'SOUTH AFRICA': 'ZA',
    'ZAF': 'ZA',
    'NIGERIA': 'NG',
    'NGA': 'NG',
    'KENYA': 'KE',
    'KEN': 'KE',
    'PAKISTAN': 'PK',
    'PAK': 'PK',
    'BANGLADESH': 'BD',
    'BGD': 'BD',
    'SRI LANKA': 'LK',
    'LKA': 'LK',
    'NEPAL': 'NP',
    'NPL': 'NP',
    'NEW ZEALAND': 'NZ',
    'NZL': 'NZ',
    'NETHERLANDS': 'NL',
    'NLD': 'NL',
    'SWITZERLAND': 'CH',
    'CHE': 'CH',
    'SWEDEN': 'SE',
    'SWE': 'SE',
    'NORWAY': 'NO',
    'NOR': 'NO',
    'SPAIN': 'ES',
    'ESP': 'ES',
    'ITALY': 'IT',
    'ITA': 'IT',
    'IRELAND': 'IE',
    'IRL': 'IE',
    'INDONESIA': 'ID',
    'IDN': 'ID',
    'PHILIPPINES': 'PH',
    'PHL': 'PH',
    'MALAYSIA': 'MY',
    'MYS': 'MY',
    'THAILAND': 'TH',
    'THA': 'TH',
    'VIETNAM': 'VN',
    'VNM': 'VN',
  };

  /// Normalizes a 2-letter country code, country name, or 3-letter alias
  static String normalizeCode(String? code) {
    if (code == null) return 'IN';
    final clean = code.trim().toUpperCase();
    if (clean.length == 2) return clean;
    return _countryAliases[clean] ?? 'IN';
  }

  /// Returns whether a country is India
  static bool isIndia(String? countryCode) {
    return normalizeCode(countryCode) == 'IN';
  }

  /// Returns a concise description of available payment rails for a country.
  /// For India (IN): UPI (Google Pay, PhonePe, Paytm, BHIM), Netbanking (50+ banks), Debit & Credit Cards.
  /// For US & International: Credit/Debit Cards (Visa, Mastercard, Amex), PayPal, Apple Pay.
  static String getPaymentMethodsDescription(String? countryCode) {
    final code = normalizeCode(countryCode);
    if (code == 'IN') {
      return 'Supports Instant UPI (Google Pay, PhonePe, Paytm, BHIM), Netbanking (50+ banks), Debit/Credit Cards, and Wallets with 256-bit SSL encryption.';
    }
    return 'Supports Credit & Debit Cards (Visa, Mastercard, American Express), PayPal, Apple Pay, and International Banking with 256-bit SSL encryption.';
  }

  /// Returns short badge summary of payment methods (e.g. for badges and footer tags)
  /// For IN: "UPI, Cards, NetBanking"
  /// For US/Intl: "Credit/Debit Cards, PayPal, Apple Pay"
  static String getPaymentMethodsSummary(String? countryCode) {
    final code = normalizeCode(countryCode);
    if (code == 'IN') {
      return 'UPI, Cards, NetBanking';
    }
    return 'Credit/Debit Cards, PayPal, Apple Pay';
  }

  /// Returns summary for recurring mandates / autopay / subscriptions
  /// For IN: "UPI AutoPay, Debit Card, or Netbanking Mandates"
  /// For US/Intl: "Credit & Debit Cards, Recurring Card Mandates"
  static String getMandateMethodsSummary(String? countryCode) {
    final code = normalizeCode(countryCode);
    if (code == 'IN') {
      return 'UPI AutoPay, Debit Card, or Netbanking Mandates';
    }
    return 'Credit & Debit Cards, International Card Mandates';
  }

  /// Returns list of available payment method badges for a country
  static List<String> getAvailablePaymentMethods(String? countryCode) {
    final code = normalizeCode(countryCode);
    if (code == 'IN') {
      return const ['UPI', 'Debit Card', 'Credit Card', 'NetBanking'];
    }
    return const ['Credit/Debit Cards', 'PayPal', 'Apple Pay', 'Bank Transfer'];
  }

  /// Checks if the country is restricted by Cashfree
  static bool isRestrictedCountry(String? countryCode) {
    if (countryCode == null) return false;
    final code = normalizeCode(countryCode);
    return restrictedCountryCodes.contains(code);
  }

  /// Checks whether Cashfree provides payment gateway services for this country
  static bool isCountrySupported(String? countryCode) {
    if (countryCode == null) return true; // Default to standard support
    final code = normalizeCode(countryCode);
    if (restrictedCountryCodes.contains(code)) return false;
    // Cashfree supports 200+ countries globally
    return true;
  }

  /// Checks whether a currency is supported by Cashfree
  static bool isCurrencySupported(String? currencyCode) {
    if (currencyCode == null) return false;
    final code = currencyCode.trim().toUpperCase();
    return supportedCurrencies.contains(code);
  }

  /// Resolves the default currency for a given country code
  static String getCurrencyForCountry(String? countryCode) {
    final code = normalizeCode(countryCode);
    final info = _countryRegistry[code];
    if (info != null && !info.isRestricted) {
      return info.currency;
    }
    // Fallback: If not explicitly mapped in registry or unknown, default to USD for international or INR for IN
    return code == 'IN' ? 'INR' : 'USD';
  }

  /// Resolves the currency symbol for a currency code
  static String getSymbolForCurrency(String? currencyCode) {
    if (currencyCode == null) return '₹';
    final code = currencyCode.trim().toUpperCase();
    return _currencySymbols[code] ?? code;
  }

  /// Resolves country info object
  static CashfreeCountryInfo getCountryInfo(String? countryCode) {
    final code = normalizeCode(countryCode);
    final existing = _countryRegistry[code];
    if (existing != null) return existing;

    final isRestricted = restrictedCountryCodes.contains(code);
    return CashfreeCountryInfo(
      code: code,
      name: 'Country ($code)',
      currency: code == 'IN' ? 'INR' : 'USD',
      currencySymbol: code == 'IN' ? '₹' : r'$',
      isRestricted: isRestricted,
    );
  }

  /// Returns minimum allowable charge amount for a given currency
  static double getMinimumAmount(String currency) {
    final cur = currency.toUpperCase();
    if (cur == 'INR') return 1.0;
    if (zeroDecimalCurrencies.contains(cur)) return 50.0;
    // Standard 2-decimal currencies (USD, EUR, GBP, CAD, AUD, etc.)
    return 0.50;
  }

  /// Formats an amount with proper currency symbol and decimals
  static String formatAmount(double amount, String currency) {
    final cur = currency.toUpperCase();
    final symbol = getSymbolForCurrency(cur);
    if (zeroDecimalCurrencies.contains(cur)) {
      return '$symbol${amount.round()}';
    }
    final formatted = amount.toStringAsFixed(2);
    // If it ends in .00, we can show clean number for whole figures or keep standard
    return '$symbol$formatted';
  }

  /// Converts an ISO 2-letter country code to a flag emoji (e.g. 'IN' -> 🇮🇳, 'US' -> 🇺🇸)
  static String countryCodeToEmoji(String countryCode) {
    if (countryCode.length != 2) return '🌐';
    final clean = countryCode.toUpperCase();
    final first = clean.codeUnitAt(0);
    final second = clean.codeUnitAt(1);
    if (first < 0x41 || first > 0x5A || second < 0x41 || second > 0x5A) {
      return '🌐';
    }
    return String.fromCharCode(first - 0x41 + 0x1F1E6) +
        String.fromCharCode(second - 0x41 + 0x1F1E6);
  }

  /// List of non-restricted countries available for user selection,
  /// sorted with India and United States pinned at the top, followed by alphabetical order.
  static List<CashfreeCountryInfo> get selectableCountries {
    final list = _countryRegistry.values.where((c) => !c.isRestricted).toList();
    list.sort((a, b) {
      if (a.code == 'IN') return -1;
      if (b.code == 'IN') return 1;
      if (a.code == 'US') return -1;
      if (b.code == 'US') return 1;
      return a.name.compareTo(b.name);
    });
    return list;
  }
}
