/// Parses the raw text content of a `.env` file into a flat key-value map.
///
/// Parsing rules:
/// - Blank lines are ignored.
/// - Lines starting with `#` are treated as comments and ignored.
/// - Keys and values are trimmed of surrounding whitespace.
/// - The first `=` in a line is the delimiter; subsequent `=` characters are
///   part of the value (e.g. `KEY=a=b` → `{'KEY': 'a=b'}`).
/// - Lines without `=` are ignored.
/// - Values wrapped in matching single or double quotes have the quotes
///   stripped. Content inside quotes is taken verbatim (inline comments are
///   **not** stripped from quoted values).
/// - For unquoted values, anything after ` #` is treated as an inline comment
///   and discarded.
/// - Both LF and CRLF line endings are handled.
class EnvParser {
  /// Parses [raw] `.env` content and returns a [Map<String, String>].
  Map<String, String> parse(String raw) {
    final result = <String, String>{};

    // Normalise CRLF → LF before splitting.
    final normalised = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    for (final line in normalised.split('\n')) {
      final trimmed = line.trim();

      // Skip blank lines and comments.
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final eqIndex = trimmed.indexOf('=');

      // Lines without '=' are not valid key-value pairs.
      if (eqIndex == -1) continue;

      final key = trimmed.substring(0, eqIndex).trim();
      final rawValue = trimmed.substring(eqIndex + 1).trim();

      // Skip entries with empty keys.
      if (key.isEmpty) continue;

      // Detect whether the value is quoted before any transformation.
      final isQuoted = rawValue.length >= 2 &&
          ((rawValue.startsWith('"') && rawValue.endsWith('"')) ||
              (rawValue.startsWith("'") && rawValue.endsWith("'")));

      final value = isQuoted
          // Quoted: strip quotes and use content verbatim — no inline comment
          // stripping (the quote boundary already delimits the value).
          ? rawValue.substring(1, rawValue.length - 1)
          // Unquoted: strip trailing inline comment first, then trim.
          : _stripInlineComment(rawValue);

      result[key] = value;
    }

    return result;
  }

  /// Removes an inline comment (anything after ` #`) from an unquoted value.
  String _stripInlineComment(String value) {
    final commentIndex = value.indexOf(' #');
    if (commentIndex != -1) {
      return value.substring(0, commentIndex).trim();
    }
    return value;
  }
}
