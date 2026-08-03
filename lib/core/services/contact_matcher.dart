import 'package:flutter/foundation.dart';

/// Intelligent multilingual contact matching.
///
/// Matching pipeline (applied in order, returns first success):
///   1. Exact case-insensitive match
///   2. Starts-with match
///   3. Contains match
///   4. Word-by-word partial match
///   5. Transliteration match (Urdu → Latin)
///   6. Fuzzy Levenshtein match (handles typos / approximations)
///
/// This ensures "Salman" finds "Salman Ahmed", "Salman Ali", and even
/// "سلمان" (transliterated to "Salman" before matching).
class ContactMatcher {
  static final ContactMatcher instance = ContactMatcher._();
  ContactMatcher._();

  // ---------------------------------------------------------------------- //
  //  Urdu → Latin transliteration map                                        //
  // ---------------------------------------------------------------------- //
  static const Map<String, String> _urduToLatinNames = {
    // Common Pakistani names
    'سلمان': 'salman',
    'علی': 'ali',
    'احمد': 'ahmed',
    'محمد': 'muhammad',
    'عمر': 'umar',
    'بلال': 'bilal',
    'حمزہ': 'hamza',
    'طلحہ': 'talha',
    'زید': 'zaid',
    'یوسف': 'yousuf',
    'عثمان': 'usman',
    'فاطمہ': 'fatima',
    'عائشہ': 'ayesha',
    'زینب': 'zainab',
    'مریم': 'maryam',
    'خدیجہ': 'khadija',
    'سارہ': 'sara',
    'ماما': 'mama',
    'امی': 'ami',
    'ابو': 'abu',
    'بھائی': 'bhai',
    'آپا': 'aapa',
    'ابا': 'aba',
    'دادا': 'dada',
    'دادی': 'dadi',
    'امی جان': 'ami jan',
    'ابا جان': 'aba jan',
    'بھائی جان': 'bhai jan',
    'رضا': 'raza',
    'حسن': 'hassan',
    'حسین': 'hussain',
    'عباس': 'abbas',
    'عمران': 'imran',
    'نواز': 'nawaz',
    'شاہد': 'shahid',
    'خالد': 'khalid',
    'وقار': 'waqar',
    'آصف': 'asif',
    'نادر': 'nadir',
    'شہریار': 'shehryar',
    'ارسلان': 'arsalan',
    'زبیر': 'zubair',
    'فیصل': 'faisal',
    'کامران': 'kamran',
    'طارق': 'tariq',
    'جاوید': 'javed',
    'وسیم': 'waseem',
  };

  // ---------------------------------------------------------------------- //
  //  Main matching method                                                    //
  // ---------------------------------------------------------------------- //

  /// Finds all contacts from [allContacts] that match [query].
  ///
  /// The query may be in English, Roman Urdu, or Urdu script.
  /// Contact names in the list are expected to be in English/Roman format.
  List<MatchedContact> findMatches(
    String query,
    List<ContactLite> allContacts,
  ) {
    if (query.trim().isEmpty || allContacts.isEmpty) return [];

    final normalizedQuery = _normalize(query);
    final transliteratedQuery = _transliterate(normalizedQuery);

    debugPrint('ContactMatcher: query="$query" normalized="$normalizedQuery" transliterated="$transliteratedQuery"');

    final scored = <MatchedContact>[];

    for (final contact in allContacts) {
      final normalizedName = _normalize(contact.name);
      final score = _scoreMatch(
        query: normalizedQuery,
        transliteratedQuery: transliteratedQuery,
        contactName: normalizedName,
      );
      if (score > 0) {
        scored.add(MatchedContact(contact: contact, score: score));
        debugPrint('ContactMatcher: matched "${contact.name}" score=$score');
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  // ---------------------------------------------------------------------- //
  //  Scoring                                                                 //
  // ---------------------------------------------------------------------- //

  int _scoreMatch({
    required String query,
    required String transliteratedQuery,
    required String contactName,
  }) {
    for (final q in {query, transliteratedQuery}) {
      if (q.isEmpty) continue;

      if (contactName == q) return 100;

      final nameWords = contactName.split(' ');
      final queryWords = q.split(' ');

      if (queryWords.every((w) => w.isNotEmpty && nameWords.any((n) => n == w))) {
        return 90;
      }

      if (contactName.startsWith(q)) return 85;

      if (contactName.contains(q)) return 75;

      for (final qw in queryWords) {
        if (qw.length < 3) continue;
        for (final nw in nameWords) {
          if (nw == qw) return 65;
          if (nw.startsWith(qw) || qw.startsWith(nw)) return 60;
        }
      }

      if (nameWords.isNotEmpty && queryWords.isNotEmpty) {
        final firstName = nameWords.first;
        final queryFirst = queryWords.first;
        if (queryFirst.length >= 3) {
          final dist = _levenshtein(firstName, queryFirst);
          final maxLen = firstName.length > queryFirst.length
              ? firstName.length
              : queryFirst.length;
          if (maxLen > 0) {
            final similarity = ((maxLen - dist) / maxLen * 100).round();
            if (similarity >= 70) return similarity - 10;
          }
        }
      }
    }

    return 0;
  }

  // ---------------------------------------------------------------------- //
  //  Normalization                                                           //
  // ---------------------------------------------------------------------- //

  /// Lowercases, removes punctuation, trims extra spaces.
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Transliterates Urdu script to Latin using the name map.
  static String _transliterate(String text) {
    for (final entry in _urduToLatinNames.entries) {
      if (text.contains(entry.key)) {
        return text.replaceAll(entry.key, entry.value).trim();
      }
    }
    return text;
  }

  // ---------------------------------------------------------------------- //
  //  Levenshtein distance                                                    //
  // ---------------------------------------------------------------------- //

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    for (var i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }

    return matrix[a.length][b.length];
  }
}

// -------------------------------------------------------------------------- //
//  Lightweight local contact representation                                   //
// -------------------------------------------------------------------------- //

/// Lightweight contact object used internally by [ContactMatcher.findMatches].
class ContactLite {
  final String id;
  final String name;
  final String phone;

  ContactLite({required this.id, required this.name, required this.phone});
}

/// A contact paired with a match quality score.
class MatchedContact {
  final ContactLite contact;
  final int score;

  MatchedContact({required this.contact, required this.score});

  String get name => contact.name;
  String get phone => contact.phone;
  String get id => contact.id;
}
