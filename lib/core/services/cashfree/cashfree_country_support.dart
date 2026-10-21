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
    'AF': CashfreeCountryInfo(code: 'AF', name: 'Afghanistan', currency: 'AFN', currencySymbol: 'Af', isRestricted: true),
    'AX': CashfreeCountryInfo(code: 'AX', name: 'Aland Islands', currency: 'EUR', currencySymbol: '€'),
    'AL': CashfreeCountryInfo(code: 'AL', name: 'Albania', currency: 'ALL', currencySymbol: 'L'),
    'DZ': CashfreeCountryInfo(code: 'DZ', name: 'Algeria', currency: 'DZD', currencySymbol: 'د.ج'),
    'AS': CashfreeCountryInfo(code: 'AS', name: 'American Samoa', currency: 'USD', currencySymbol: r'$'),
    'AD': CashfreeCountryInfo(code: 'AD', name: 'Andorra', currency: 'EUR', currencySymbol: '€'),
    'AO': CashfreeCountryInfo(code: 'AO', name: 'Angola', currency: 'AOA', currencySymbol: 'Kz'),
    'AI': CashfreeCountryInfo(code: 'AI', name: 'Anguilla', currency: 'XCD', currencySymbol: r'$'),
    'AQ': CashfreeCountryInfo(code: 'AQ', name: 'Antarctica', currency: 'USD', currencySymbol: r'$'),
    'AG': CashfreeCountryInfo(code: 'AG', name: 'Antigua and Barbuda', currency: 'XCD', currencySymbol: r'$'),
    'AR': CashfreeCountryInfo(code: 'AR', name: 'Argentina', currency: 'ARS', currencySymbol: r'$'),
    'AM': CashfreeCountryInfo(code: 'AM', name: 'Armenia', currency: 'AMD', currencySymbol: '֏'),
    'AW': CashfreeCountryInfo(code: 'AW', name: 'Aruba', currency: 'AWG', currencySymbol: 'ƒ'),
    'AU': CashfreeCountryInfo(code: 'AU', name: 'Australia', currency: 'AUD', currencySymbol: r'A$'),
    'AT': CashfreeCountryInfo(code: 'AT', name: 'Austria', currency: 'EUR', currencySymbol: '€'),
    'AZ': CashfreeCountryInfo(code: 'AZ', name: 'Azerbaijan', currency: 'AZN', currencySymbol: '₼'),
    'BS': CashfreeCountryInfo(code: 'BS', name: 'Bahamas', currency: 'BSD', currencySymbol: r'$'),
    'BH': CashfreeCountryInfo(code: 'BH', name: 'Bahrain', currency: 'BHD', currencySymbol: 'BD'),
    'BD': CashfreeCountryInfo(code: 'BD', name: 'Bangladesh', currency: 'BDT', currencySymbol: '৳'),
    'BB': CashfreeCountryInfo(code: 'BB', name: 'Barbados', currency: 'BBD', currencySymbol: r'$'),
    'BY': CashfreeCountryInfo(code: 'BY', name: 'Belarus', currency: 'BYN', currencySymbol: 'Br', isRestricted: true),
    'BE': CashfreeCountryInfo(code: 'BE', name: 'Belgium', currency: 'EUR', currencySymbol: '€'),
    'BZ': CashfreeCountryInfo(code: 'BZ', name: 'Belize', currency: 'BZD', currencySymbol: r'BZ$'),
    'BJ': CashfreeCountryInfo(code: 'BJ', name: 'Benin', currency: 'XOF', currencySymbol: 'CFA'),
    'BM': CashfreeCountryInfo(code: 'BM', name: 'Bermuda', currency: 'BMD', currencySymbol: r'$'),
    'BT': CashfreeCountryInfo(code: 'BT', name: 'Bhutan', currency: 'BTN', currencySymbol: 'Nu.'),
    'BO': CashfreeCountryInfo(code: 'BO', name: 'Bolivia', currency: 'BOB', currencySymbol: 'Bs.'),
    'BQ': CashfreeCountryInfo(code: 'BQ', name: 'Bonaire, Sint Eustatius and Saba', currency: 'USD', currencySymbol: r'$'),
    'BA': CashfreeCountryInfo(code: 'BA', name: 'Bosnia and Herzegovina', currency: 'BAM', currencySymbol: 'KM'),
    'BW': CashfreeCountryInfo(code: 'BW', name: 'Botswana', currency: 'BWP', currencySymbol: 'P'),
    'BR': CashfreeCountryInfo(code: 'BR', name: 'Brazil', currency: 'BRL', currencySymbol: r'R$'),
    'IO': CashfreeCountryInfo(code: 'IO', name: 'British Indian Ocean Territory', currency: 'USD', currencySymbol: r'$'),
    'VG': CashfreeCountryInfo(code: 'VG', name: 'British Virgin Islands', currency: 'USD', currencySymbol: r'$'),
    'BN': CashfreeCountryInfo(code: 'BN', name: 'Brunei', currency: 'BND', currencySymbol: r'B$'),
    'BG': CashfreeCountryInfo(code: 'BG', name: 'Bulgaria', currency: 'BGN', currencySymbol: 'лв'),
    'BF': CashfreeCountryInfo(code: 'BF', name: 'Burkina Faso', currency: 'XOF', currencySymbol: 'CFA'),
    'BI': CashfreeCountryInfo(code: 'BI', name: 'Burundi', currency: 'BIF', currencySymbol: 'FBu'),
    'CV': CashfreeCountryInfo(code: 'CV', name: 'Cabo Verde', currency: 'CVE', currencySymbol: r'$'),
    'KH': CashfreeCountryInfo(code: 'KH', name: 'Cambodia', currency: 'KHR', currencySymbol: '៛'),
    'CM': CashfreeCountryInfo(code: 'CM', name: 'Cameroon', currency: 'XAF', currencySymbol: 'FCFA'),
    'CA': CashfreeCountryInfo(code: 'CA', name: 'Canada', currency: 'CAD', currencySymbol: r'CA$'),
    'KY': CashfreeCountryInfo(code: 'KY', name: 'Cayman Islands', currency: 'KYD', currencySymbol: r'$'),
    'CF': CashfreeCountryInfo(code: 'CF', name: 'Central African Republic', currency: 'XAF', currencySymbol: 'FCFA'),
    'TD': CashfreeCountryInfo(code: 'TD', name: 'Chad', currency: 'XAF', currencySymbol: 'FCFA'),
    'CL': CashfreeCountryInfo(code: 'CL', name: 'Chile', currency: 'CLP', currencySymbol: r'CLP$'),
    'CN': CashfreeCountryInfo(code: 'CN', name: 'China', currency: 'CNY', currencySymbol: '¥'),
    'CX': CashfreeCountryInfo(code: 'CX', name: 'Christmas Island', currency: 'AUD', currencySymbol: r'A$'),
    'CC': CashfreeCountryInfo(code: 'CC', name: 'Cocos (Keeling) Islands', currency: 'AUD', currencySymbol: r'A$'),
    'CO': CashfreeCountryInfo(code: 'CO', name: 'Colombia', currency: 'COP', currencySymbol: r'COL$'),
    'KM': CashfreeCountryInfo(code: 'KM', name: 'Comoros', currency: 'KMF', currencySymbol: 'CF'),
    'CG': CashfreeCountryInfo(code: 'CG', name: 'Congo', currency: 'XAF', currencySymbol: 'FCFA'),
    'CD': CashfreeCountryInfo(code: 'CD', name: 'DR Congo', currency: 'CDF', currencySymbol: 'FC'),
    'CK': CashfreeCountryInfo(code: 'CK', name: 'Cook Islands', currency: 'NZD', currencySymbol: r'NZ$'),
    'CR': CashfreeCountryInfo(code: 'CR', name: 'Costa Rica', currency: 'CRC', currencySymbol: '₡'),
    'CI': CashfreeCountryInfo(code: 'CI', name: 'Ivory Coast', currency: 'XOF', currencySymbol: 'CFA'),
    'HR': CashfreeCountryInfo(code: 'HR', name: 'Croatia', currency: 'EUR', currencySymbol: '€'),
    'CU': CashfreeCountryInfo(code: 'CU', name: 'Cuba', currency: 'CUP', currencySymbol: r'$', isRestricted: true),
    'CW': CashfreeCountryInfo(code: 'CW', name: 'Curacao', currency: 'ANG', currencySymbol: 'ƒ'),
    'CY': CashfreeCountryInfo(code: 'CY', name: 'Cyprus', currency: 'EUR', currencySymbol: '€'),
    'CZ': CashfreeCountryInfo(code: 'CZ', name: 'Czech Republic', currency: 'CZK', currencySymbol: 'Kč'),
    'DK': CashfreeCountryInfo(code: 'DK', name: 'Denmark', currency: 'DKK', currencySymbol: 'kr.'),
    'DJ': CashfreeCountryInfo(code: 'DJ', name: 'Djibouti', currency: 'DJF', currencySymbol: 'Fdj'),
    'DM': CashfreeCountryInfo(code: 'DM', name: 'Dominica', currency: 'XCD', currencySymbol: r'$'),
    'DO': CashfreeCountryInfo(code: 'DO', name: 'Dominican Republic', currency: 'DOP', currencySymbol: r'RD$'),
    'EC': CashfreeCountryInfo(code: 'EC', name: 'Ecuador', currency: 'USD', currencySymbol: r'$'),
    'EG': CashfreeCountryInfo(code: 'EG', name: 'Egypt', currency: 'EGP', currencySymbol: 'E£'),
    'SV': CashfreeCountryInfo(code: 'SV', name: 'El Salvador', currency: 'USD', currencySymbol: r'$'),
    'GQ': CashfreeCountryInfo(code: 'GQ', name: 'Equatorial Guinea', currency: 'XAF', currencySymbol: 'FCFA'),
    'ER': CashfreeCountryInfo(code: 'ER', name: 'Eritrea', currency: 'ERN', currencySymbol: 'Nfk'),
    'EE': CashfreeCountryInfo(code: 'EE', name: 'Estonia', currency: 'EUR', currencySymbol: '€'),
    'SZ': CashfreeCountryInfo(code: 'SZ', name: 'Eswatini', currency: 'SZL', currencySymbol: 'E'),
    'ET': CashfreeCountryInfo(code: 'ET', name: 'Ethiopia', currency: 'ETB', currencySymbol: 'Br'),
    'FK': CashfreeCountryInfo(code: 'FK', name: 'Falkland Islands', currency: 'FKP', currencySymbol: '£'),
    'FO': CashfreeCountryInfo(code: 'FO', name: 'Faroe Islands', currency: 'DKK', currencySymbol: 'kr.'),
    'FJ': CashfreeCountryInfo(code: 'FJ', name: 'Fiji', currency: 'FJD', currencySymbol: r'FJ$'),
    'FI': CashfreeCountryInfo(code: 'FI', name: 'Finland', currency: 'EUR', currencySymbol: '€'),
    'FR': CashfreeCountryInfo(code: 'FR', name: 'France', currency: 'EUR', currencySymbol: '€'),
    'GF': CashfreeCountryInfo(code: 'GF', name: 'French Guiana', currency: 'EUR', currencySymbol: '€'),
    'PF': CashfreeCountryInfo(code: 'PF', name: 'French Polynesia', currency: 'XPF', currencySymbol: '₣'),
    'GA': CashfreeCountryInfo(code: 'GA', name: 'Gabon', currency: 'XAF', currencySymbol: 'FCFA'),
    'GM': CashfreeCountryInfo(code: 'GM', name: 'Gambia', currency: 'GMD', currencySymbol: 'D'),
    'GE': CashfreeCountryInfo(code: 'GE', name: 'Georgia', currency: 'GEL', currencySymbol: '₾'),
    'DE': CashfreeCountryInfo(code: 'DE', name: 'Germany', currency: 'EUR', currencySymbol: '€'),
    'GH': CashfreeCountryInfo(code: 'GH', name: 'Ghana', currency: 'GHS', currencySymbol: 'GH₵'),
    'GI': CashfreeCountryInfo(code: 'GI', name: 'Gibraltar', currency: 'GIP', currencySymbol: '£'),
    'GR': CashfreeCountryInfo(code: 'GR', name: 'Greece', currency: 'EUR', currencySymbol: '€'),
    'GL': CashfreeCountryInfo(code: 'GL', name: 'Greenland', currency: 'DKK', currencySymbol: 'kr.'),
    'GD': CashfreeCountryInfo(code: 'GD', name: 'Grenada', currency: 'XCD', currencySymbol: r'$'),
    'GP': CashfreeCountryInfo(code: 'GP', name: 'Guadeloupe', currency: 'EUR', currencySymbol: '€'),
    'GU': CashfreeCountryInfo(code: 'GU', name: 'Guam', currency: 'USD', currencySymbol: r'$'),
    'GT': CashfreeCountryInfo(code: 'GT', name: 'Guatemala', currency: 'GTQ', currencySymbol: 'Q'),
    'GG': CashfreeCountryInfo(code: 'GG', name: 'Guernsey', currency: 'GBP', currencySymbol: '£'),
    'GN': CashfreeCountryInfo(code: 'GN', name: 'Guinea', currency: 'GNF', currencySymbol: 'FG'),
    'GW': CashfreeCountryInfo(code: 'GW', name: 'Guinea-Bissau', currency: 'XOF', currencySymbol: 'CFA'),
    'GY': CashfreeCountryInfo(code: 'GY', name: 'Guyana', currency: 'GYD', currencySymbol: r'GY$'),
    'HT': CashfreeCountryInfo(code: 'HT', name: 'Haiti', currency: 'HTG', currencySymbol: 'G'),
    'HN': CashfreeCountryInfo(code: 'HN', name: 'Honduras', currency: 'HNL', currencySymbol: 'L'),
    'HK': CashfreeCountryInfo(code: 'HK', name: 'Hong Kong', currency: 'HKD', currencySymbol: r'HK$'),
    'HU': CashfreeCountryInfo(code: 'HU', name: 'Hungary', currency: 'HUF', currencySymbol: 'Ft'),
    'IS': CashfreeCountryInfo(code: 'IS', name: 'Iceland', currency: 'ISK', currencySymbol: 'kr'),
    'IN': CashfreeCountryInfo(code: 'IN', name: 'India', currency: 'INR', currencySymbol: '₹'),
    'ID': CashfreeCountryInfo(code: 'ID', name: 'Indonesia', currency: 'IDR', currencySymbol: 'Rp'),
    'IR': CashfreeCountryInfo(code: 'IR', name: 'Iran', currency: 'IRR', currencySymbol: '﷼', isRestricted: true),
    'IQ': CashfreeCountryInfo(code: 'IQ', name: 'Iraq', currency: 'IQD', currencySymbol: 'ع.د', isRestricted: true),
    'IE': CashfreeCountryInfo(code: 'IE', name: 'Ireland', currency: 'EUR', currencySymbol: '€'),
    'IM': CashfreeCountryInfo(code: 'IM', name: 'Isle of Man', currency: 'GBP', currencySymbol: '£'),
    'IL': CashfreeCountryInfo(code: 'IL', name: 'Israel', currency: 'ILS', currencySymbol: '₪'),
    'IT': CashfreeCountryInfo(code: 'IT', name: 'Italy', currency: 'EUR', currencySymbol: '€'),
    'JM': CashfreeCountryInfo(code: 'JM', name: 'Jamaica', currency: 'JMD', currencySymbol: r'J$'),
    'JP': CashfreeCountryInfo(code: 'JP', name: 'Japan', currency: 'JPY', currencySymbol: '¥'),
    'JE': CashfreeCountryInfo(code: 'JE', name: 'Jersey', currency: 'GBP', currencySymbol: '£'),
    'JO': CashfreeCountryInfo(code: 'JO', name: 'Jordan', currency: 'JOD', currencySymbol: 'JD'),
    'KZ': CashfreeCountryInfo(code: 'KZ', name: 'Kazakhstan', currency: 'KZT', currencySymbol: '₸'),
    'KE': CashfreeCountryInfo(code: 'KE', name: 'Kenya', currency: 'KES', currencySymbol: 'KSh'),
    'KI': CashfreeCountryInfo(code: 'KI', name: 'Kiribati', currency: 'AUD', currencySymbol: r'$'),
    'KP': CashfreeCountryInfo(code: 'KP', name: 'North Korea', currency: 'KPW', currencySymbol: '₩', isRestricted: true),
    'KR': CashfreeCountryInfo(code: 'KR', name: 'South Korea', currency: 'KRW', currencySymbol: '₩'),
    'KW': CashfreeCountryInfo(code: 'KW', name: 'Kuwait', currency: 'KWD', currencySymbol: 'KWD'),
    'KG': CashfreeCountryInfo(code: 'KG', name: 'Kyrgyzstan', currency: 'KGS', currencySymbol: 'сом'),
    'LA': CashfreeCountryInfo(code: 'LA', name: 'Laos', currency: 'LAK', currencySymbol: '₭'),
    'LV': CashfreeCountryInfo(code: 'LV', name: 'Latvia', currency: 'EUR', currencySymbol: '€'),
    'LB': CashfreeCountryInfo(code: 'LB', name: 'Lebanon', currency: 'LBP', currencySymbol: 'LL'),
    'LS': CashfreeCountryInfo(code: 'LS', name: 'Lesotho', currency: 'LSL', currencySymbol: 'L'),
    'LR': CashfreeCountryInfo(code: 'LR', name: 'Liberia', currency: 'LRD', currencySymbol: r'$'),
    'LY': CashfreeCountryInfo(code: 'LY', name: 'Libya', currency: 'LYD', currencySymbol: 'LD'),
    'LI': CashfreeCountryInfo(code: 'LI', name: 'Liechtenstein', currency: 'CHF', currencySymbol: 'CHF'),
    'LT': CashfreeCountryInfo(code: 'LT', name: 'Lithuania', currency: 'EUR', currencySymbol: '€'),
    'LU': CashfreeCountryInfo(code: 'LU', name: 'Luxembourg', currency: 'EUR', currencySymbol: '€'),
    'MO': CashfreeCountryInfo(code: 'MO', name: 'Macau', currency: 'MOP', currencySymbol: r'MOP$'),
    'MG': CashfreeCountryInfo(code: 'MG', name: 'Madagascar', currency: 'MGA', currencySymbol: 'Ar'),
    'MW': CashfreeCountryInfo(code: 'MW', name: 'Malawi', currency: 'MWK', currencySymbol: 'MK'),
    'MY': CashfreeCountryInfo(code: 'MY', name: 'Malaysia', currency: 'MYR', currencySymbol: 'RM'),
    'MV': CashfreeCountryInfo(code: 'MV', name: 'Maldives', currency: 'MVR', currencySymbol: 'Rf'),
    'ML': CashfreeCountryInfo(code: 'ML', name: 'Mali', currency: 'XOF', currencySymbol: 'CFA'),
    'MT': CashfreeCountryInfo(code: 'MT', name: 'Malta', currency: 'EUR', currencySymbol: '€'),
    'MH': CashfreeCountryInfo(code: 'MH', name: 'Marshall Islands', currency: 'USD', currencySymbol: r'$'),
    'MQ': CashfreeCountryInfo(code: 'MQ', name: 'Martinique', currency: 'EUR', currencySymbol: '€'),
    'MR': CashfreeCountryInfo(code: 'MR', name: 'Mauritania', currency: 'MRU', currencySymbol: 'UM'),
    'MU': CashfreeCountryInfo(code: 'MU', name: 'Mauritius', currency: 'MUR', currencySymbol: '₨'),
    'YT': CashfreeCountryInfo(code: 'YT', name: 'Mayotte', currency: 'EUR', currencySymbol: '€'),
    'MX': CashfreeCountryInfo(code: 'MX', name: 'Mexico', currency: 'MXN', currencySymbol: r'MX$'),
    'FM': CashfreeCountryInfo(code: 'FM', name: 'Micronesia', currency: 'USD', currencySymbol: r'$'),
    'MD': CashfreeCountryInfo(code: 'MD', name: 'Moldova', currency: 'MDL', currencySymbol: 'L'),
    'MC': CashfreeCountryInfo(code: 'MC', name: 'Monaco', currency: 'EUR', currencySymbol: '€'),
    'MN': CashfreeCountryInfo(code: 'MN', name: 'Mongolia', currency: 'MNT', currencySymbol: '₮'),
    'ME': CashfreeCountryInfo(code: 'ME', name: 'Montenegro', currency: 'EUR', currencySymbol: '€'),
    'MS': CashfreeCountryInfo(code: 'MS', name: 'Montserrat', currency: 'XCD', currencySymbol: r'$'),
    'MA': CashfreeCountryInfo(code: 'MA', name: 'Morocco', currency: 'MAD', currencySymbol: 'MAD'),
    'MZ': CashfreeCountryInfo(code: 'MZ', name: 'Mozambique', currency: 'MZN', currencySymbol: 'MT'),
    'MM': CashfreeCountryInfo(code: 'MM', name: 'Myanmar', currency: 'MMK', currencySymbol: 'K'),
    'NA': CashfreeCountryInfo(code: 'NA', name: 'Namibia', currency: 'NAD', currencySymbol: r'N$'),
    'NR': CashfreeCountryInfo(code: 'NR', name: 'Nauru', currency: 'AUD', currencySymbol: r'$'),
    'NP': CashfreeCountryInfo(code: 'NP', name: 'Nepal', currency: 'NPR', currencySymbol: '₨'),
    'NL': CashfreeCountryInfo(code: 'NL', name: 'Netherlands', currency: 'EUR', currencySymbol: '€'),
    'NC': CashfreeCountryInfo(code: 'NC', name: 'New Caledonia', currency: 'XPF', currencySymbol: '₣'),
    'NZ': CashfreeCountryInfo(code: 'NZ', name: 'New Zealand', currency: 'NZD', currencySymbol: r'NZ$'),
    'NI': CashfreeCountryInfo(code: 'NI', name: 'Nicaragua', currency: 'NIO', currencySymbol: r'C$'),
    'NE': CashfreeCountryInfo(code: 'NE', name: 'Niger', currency: 'XOF', currencySymbol: 'CFA'),
    'NG': CashfreeCountryInfo(code: 'NG', name: 'Nigeria', currency: 'NGN', currencySymbol: '₦'),
    'NU': CashfreeCountryInfo(code: 'NU', name: 'Niue', currency: 'NZD', currencySymbol: r'NZ$'),
    'NF': CashfreeCountryInfo(code: 'NF', name: 'Norfolk Island', currency: 'AUD', currencySymbol: r'A$'),
    'MK': CashfreeCountryInfo(code: 'MK', name: 'North Macedonia', currency: 'MKD', currencySymbol: 'ден'),
    'MP': CashfreeCountryInfo(code: 'MP', name: 'Northern Mariana Islands', currency: 'USD', currencySymbol: r'$'),
    'NO': CashfreeCountryInfo(code: 'NO', name: 'Norway', currency: 'NOK', currencySymbol: 'kr'),
    'OM': CashfreeCountryInfo(code: 'OM', name: 'Oman', currency: 'OMR', currencySymbol: 'OMR'),
    'PK': CashfreeCountryInfo(code: 'PK', name: 'Pakistan', currency: 'PKR', currencySymbol: '₨', isRestricted: true),
    'PW': CashfreeCountryInfo(code: 'PW', name: 'Palau', currency: 'USD', currencySymbol: r'$'),
    'PS': CashfreeCountryInfo(code: 'PS', name: 'Palestine', currency: 'ILS', currencySymbol: '₪'),
    'PA': CashfreeCountryInfo(code: 'PA', name: 'Panama', currency: 'PAB', currencySymbol: 'B/.'),
    'PG': CashfreeCountryInfo(code: 'PG', name: 'Papua New Guinea', currency: 'PGK', currencySymbol: 'K'),
    'PY': CashfreeCountryInfo(code: 'PY', name: 'Paraguay', currency: 'PYG', currencySymbol: '₲'),
    'PE': CashfreeCountryInfo(code: 'PE', name: 'Peru', currency: 'PEN', currencySymbol: 'S/'),
    'PH': CashfreeCountryInfo(code: 'PH', name: 'Philippines', currency: 'PHP', currencySymbol: '₱'),
    'PN': CashfreeCountryInfo(code: 'PN', name: 'Pitcairn', currency: 'NZD', currencySymbol: r'NZ$'),
    'PL': CashfreeCountryInfo(code: 'PL', name: 'Poland', currency: 'PLN', currencySymbol: 'zł'),
    'PT': CashfreeCountryInfo(code: 'PT', name: 'Portugal', currency: 'EUR', currencySymbol: '€'),
    'PR': CashfreeCountryInfo(code: 'PR', name: 'Puerto Rico', currency: 'USD', currencySymbol: r'$'),
    'QA': CashfreeCountryInfo(code: 'QA', name: 'Qatar', currency: 'QAR', currencySymbol: 'QAR'),
    'RE': CashfreeCountryInfo(code: 'RE', name: 'Reunion', currency: 'EUR', currencySymbol: '€'),
    'RO': CashfreeCountryInfo(code: 'RO', name: 'Romania', currency: 'RON', currencySymbol: 'lei'),
    'RU': CashfreeCountryInfo(code: 'RU', name: 'Russia', currency: 'RUB', currencySymbol: '₽', isRestricted: true),
    'RW': CashfreeCountryInfo(code: 'RW', name: 'Rwanda', currency: 'RWF', currencySymbol: 'RF'),
    'BL': CashfreeCountryInfo(code: 'BL', name: 'Saint Barthelemy', currency: 'EUR', currencySymbol: '€'),
    'SH': CashfreeCountryInfo(code: 'SH', name: 'Saint Helena', currency: 'SHP', currencySymbol: '£'),
    'KN': CashfreeCountryInfo(code: 'KN', name: 'Saint Kitts and Nevis', currency: 'XCD', currencySymbol: r'$'),
    'LC': CashfreeCountryInfo(code: 'LC', name: 'Saint Lucia', currency: 'XCD', currencySymbol: r'$'),
    'MF': CashfreeCountryInfo(code: 'MF', name: 'Saint Martin', currency: 'EUR', currencySymbol: '€'),
    'PM': CashfreeCountryInfo(code: 'PM', name: 'Saint Pierre and Miquelon', currency: 'EUR', currencySymbol: '€'),
    'VC': CashfreeCountryInfo(code: 'VC', name: 'Saint Vincent and the Grenadines', currency: 'XCD', currencySymbol: r'$'),
    'WS': CashfreeCountryInfo(code: 'WS', name: 'Samoa', currency: 'WST', currencySymbol: r'WS$'),
    'SM': CashfreeCountryInfo(code: 'SM', name: 'San Marino', currency: 'EUR', currencySymbol: '€'),
    'ST': CashfreeCountryInfo(code: 'ST', name: 'Sao Tome and Principe', currency: 'STN', currencySymbol: 'Db'),
    'SA': CashfreeCountryInfo(code: 'SA', name: 'Saudi Arabia', currency: 'SAR', currencySymbol: 'SAR'),
    'SN': CashfreeCountryInfo(code: 'SN', name: 'Senegal', currency: 'XOF', currencySymbol: 'CFA'),
    'RS': CashfreeCountryInfo(code: 'RS', name: 'Serbia', currency: 'RSD', currencySymbol: 'din'),
    'SC': CashfreeCountryInfo(code: 'SC', name: 'Seychelles', currency: 'SCR', currencySymbol: 'SR'),
    'SL': CashfreeCountryInfo(code: 'SL', name: 'Sierra Leone', currency: 'SLE', currencySymbol: 'Le'),
    'SG': CashfreeCountryInfo(code: 'SG', name: 'Singapore', currency: 'SGD', currencySymbol: r'S$'),
    'SX': CashfreeCountryInfo(code: 'SX', name: 'Sint Maarten', currency: 'ANG', currencySymbol: 'ƒ'),
    'SK': CashfreeCountryInfo(code: 'SK', name: 'Slovakia', currency: 'EUR', currencySymbol: '€'),
    'SI': CashfreeCountryInfo(code: 'SI', name: 'Slovenia', currency: 'EUR', currencySymbol: '€'),
    'SB': CashfreeCountryInfo(code: 'SB', name: 'Solomon Islands', currency: 'SBD', currencySymbol: r'SI$'),
    'SO': CashfreeCountryInfo(code: 'SO', name: 'Somalia', currency: 'SOS', currencySymbol: 'Sh'),
    'ZA': CashfreeCountryInfo(code: 'ZA', name: 'South Africa', currency: 'ZAR', currencySymbol: 'R'),
    'SS': CashfreeCountryInfo(code: 'SS', name: 'South Sudan', currency: 'SSP', currencySymbol: '£'),
    'ES': CashfreeCountryInfo(code: 'ES', name: 'Spain', currency: 'EUR', currencySymbol: '€'),
    'LK': CashfreeCountryInfo(code: 'LK', name: 'Sri Lanka', currency: 'LKR', currencySymbol: '₨'),
    'SD': CashfreeCountryInfo(code: 'SD', name: 'Sudan', currency: 'SDG', currencySymbol: 'ج.س.', isRestricted: true),
    'SR': CashfreeCountryInfo(code: 'SR', name: 'Suriname', currency: 'SRD', currencySymbol: r'$'),
    'SJ': CashfreeCountryInfo(code: 'SJ', name: 'Svalbard and Jan Mayen', currency: 'NOK', currencySymbol: 'kr'),
    'SE': CashfreeCountryInfo(code: 'SE', name: 'Sweden', currency: 'SEK', currencySymbol: 'kr'),
    'CH': CashfreeCountryInfo(code: 'CH', name: 'Switzerland', currency: 'CHF', currencySymbol: 'CHF'),
    'SY': CashfreeCountryInfo(code: 'SY', name: 'Syria', currency: 'SYP', currencySymbol: '£', isRestricted: true),
    'TW': CashfreeCountryInfo(code: 'TW', name: 'Taiwan', currency: 'TWD', currencySymbol: r'NT$'),
    'TJ': CashfreeCountryInfo(code: 'TJ', name: 'Tajikistan', currency: 'TJS', currencySymbol: 'ЅМ'),
    'TZ': CashfreeCountryInfo(code: 'TZ', name: 'Tanzania', currency: 'TZS', currencySymbol: 'TSh'),
    'TH': CashfreeCountryInfo(code: 'TH', name: 'Thailand', currency: 'THB', currencySymbol: '฿'),
    'TL': CashfreeCountryInfo(code: 'TL', name: 'Timor-Leste', currency: 'USD', currencySymbol: r'$'),
    'TG': CashfreeCountryInfo(code: 'TG', name: 'Togo', currency: 'XOF', currencySymbol: 'CFA'),
    'TK': CashfreeCountryInfo(code: 'TK', name: 'Tokelau', currency: 'NZD', currencySymbol: r'NZ$'),
    'TO': CashfreeCountryInfo(code: 'TO', name: 'Tonga', currency: 'TOP', currencySymbol: r'T$'),
    'TT': CashfreeCountryInfo(code: 'TT', name: 'Trinidad and Tobago', currency: 'TTD', currencySymbol: r'TT$'),
    'TN': CashfreeCountryInfo(code: 'TN', name: 'Tunisia', currency: 'TND', currencySymbol: 'DT'),
    'TR': CashfreeCountryInfo(code: 'TR', name: 'Turkey', currency: 'TRY', currencySymbol: '₺'),
    'TM': CashfreeCountryInfo(code: 'TM', name: 'Turkmenistan', currency: 'TMT', currencySymbol: 'T'),
    'TC': CashfreeCountryInfo(code: 'TC', name: 'Turks and Caicos Islands', currency: 'USD', currencySymbol: r'$'),
    'TV': CashfreeCountryInfo(code: 'TV', name: 'Tuvalu', currency: 'AUD', currencySymbol: r'$'),
    'UG': CashfreeCountryInfo(code: 'UG', name: 'Uganda', currency: 'UGX', currencySymbol: 'USh'),
    'UA': CashfreeCountryInfo(code: 'UA', name: 'Ukraine', currency: 'UAH', currencySymbol: '₴'),
    'AE': CashfreeCountryInfo(code: 'AE', name: 'United Arab Emirates', currency: 'AED', currencySymbol: 'AED'),
    'GB': CashfreeCountryInfo(code: 'GB', name: 'United Kingdom', currency: 'GBP', currencySymbol: '£'),
    'US': CashfreeCountryInfo(code: 'US', name: 'United States', currency: 'USD', currencySymbol: r'$'),
    'UY': CashfreeCountryInfo(code: 'UY', name: 'Uruguay', currency: 'UYU', currencySymbol: r'$U'),
    'UZ': CashfreeCountryInfo(code: 'UZ', name: 'Uzbekistan', currency: 'UZS', currencySymbol: "so'm"),
    'VU': CashfreeCountryInfo(code: 'VU', name: 'Vanuatu', currency: 'VUV', currencySymbol: 'VT'),
    'VA': CashfreeCountryInfo(code: 'VA', name: 'Vatican City', currency: 'EUR', currencySymbol: '€'),
    'VE': CashfreeCountryInfo(code: 'VE', name: 'Venezuela', currency: 'VES', currencySymbol: 'Bs.'),
    'VN': CashfreeCountryInfo(code: 'VN', name: 'Vietnam', currency: 'VND', currencySymbol: '₫'),
    'VI': CashfreeCountryInfo(code: 'VI', name: 'U.S. Virgin Islands', currency: 'USD', currencySymbol: r'$'),
    'WF': CashfreeCountryInfo(code: 'WF', name: 'Wallis and Futuna', currency: 'XPF', currencySymbol: '₣'),
    'YE': CashfreeCountryInfo(code: 'YE', name: 'Yemen', currency: 'YER', currencySymbol: '﷼'),
    'ZM': CashfreeCountryInfo(code: 'ZM', name: 'Zambia', currency: 'ZMW', currencySymbol: 'ZK'),
    'ZW': CashfreeCountryInfo(code: 'ZW', name: 'Zimbabwe', currency: 'ZWG', currencySymbol: 'ZiG'),
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
  /// Cached unmodifiable list of all 240+ countries and territories worldwide,
  /// sorted with India and United States pinned at the top, followed by alphabetical order.
  static final List<CashfreeCountryInfo> allCountries = _buildAllCountries();

  /// Cached unmodifiable list of non-restricted countries.
  static final List<CashfreeCountryInfo> selectableCountries = _buildSelectableCountries();

  static List<CashfreeCountryInfo> _buildAllCountries() {
    final list = _countryRegistry.values.toList();
    list.sort((a, b) {
      if (a.code == 'IN') return -1;
      if (b.code == 'IN') return 1;
      if (a.code == 'US') return -1;
      if (b.code == 'US') return 1;
      return a.name.compareTo(b.name);
    });
    return List.unmodifiable(list);
  }

  static List<CashfreeCountryInfo> _buildSelectableCountries() {
    final list = _countryRegistry.values.where((c) => !c.isRestricted).toList();
    list.sort((a, b) {
      if (a.code == 'IN') return -1;
      if (b.code == 'IN') return 1;
      if (a.code == 'US') return -1;
      if (b.code == 'US') return 1;
      return a.name.compareTo(b.name);
    });
    return List.unmodifiable(list);
  }
}
