import 'package:flutter_env_switch/core/env_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late EnvParser parser;

  setUp(() => parser = EnvParser());

  group('EnvParser', () {
    test('parses simple KEY=VALUE pairs', () {
      const raw = '''
BASE_URL=https://api.example.com
TIMEOUT=30
''';
      final result = parser.parse(raw);
      expect(result['BASE_URL'], 'https://api.example.com');
      expect(result['TIMEOUT'], '30');
    });

    test('ignores lines starting with #', () {
      const raw = '''
# This is a comment
KEY=value
''';
      final result = parser.parse(raw);
      expect(result.containsKey('# This is a comment'), isFalse);
      expect(result['KEY'], 'value');
    });

    test('ignores blank lines', () {
      const raw = '\n\nKEY=value\n\n';
      final result = parser.parse(raw);
      expect(result.length, 1);
    });

    test('preserves = characters inside values', () {
      const raw = 'TOKEN=abc=def=ghi';
      final result = parser.parse(raw);
      expect(result['TOKEN'], 'abc=def=ghi');
    });

    test('trims whitespace from keys and values', () {
      const raw = '  KEY  =  value  ';
      final result = parser.parse(raw);
      expect(result['KEY'], 'value');
    });

    test('strips double-quoted values', () {
      const raw = 'KEY="hello world"';
      final result = parser.parse(raw);
      expect(result['KEY'], 'hello world');
    });

    test('strips single-quoted values', () {
      const raw = "KEY='hello world'";
      final result = parser.parse(raw);
      expect(result['KEY'], 'hello world');
    });

    test('strips inline comment after space-hash', () {
      const raw = 'KEY=value # this is a comment';
      final result = parser.parse(raw);
      expect(result['KEY'], 'value');
    });

    test('ignores lines without = delimiter', () {
      const raw = 'INVALID_LINE\nKEY=value';
      final result = parser.parse(raw);
      expect(result.containsKey('INVALID_LINE'), isFalse);
      expect(result['KEY'], 'value');
    });

    test('ignores entries with empty keys', () {
      const raw = '=value';
      final result = parser.parse(raw);
      expect(result.isEmpty, isTrue);
    });

    test('handles empty string input', () {
      final result = parser.parse('');
      expect(result.isEmpty, isTrue);
    });

    test('returns correct count for multi-line input', () {
      const raw = '''
A=1
B=2
# comment
C=3
''';
      final result = parser.parse(raw);
      expect(result.length, 3);
    });

    test('last duplicate key wins', () {
      const raw = '''
KEY=first
KEY=second
''';
      final result = parser.parse(raw);
      expect(result['KEY'], 'second');
    });

    test('handles empty value (KEY=)', () {
      const raw = 'KEY=';
      final result = parser.parse(raw);
      expect(result['KEY'], '');
    });

    test('handles CRLF line endings', () {
      const raw = 'A=1\r\nB=2\r\nC=3';
      final result = parser.parse(raw);
      expect(result['A'], '1');
      expect(result['B'], '2');
      expect(result['C'], '3');
    });

    test('handles CR-only line endings', () {
      const raw = 'A=1\rB=2';
      final result = parser.parse(raw);
      expect(result['A'], '1');
      expect(result['B'], '2');
    });

    test('does NOT strip inline # from quoted values', () {
      const raw = 'KEY="foo # not a comment"';
      final result = parser.parse(raw);
      expect(result['KEY'], 'foo # not a comment');
    });

    test('strips inline # from unquoted values', () {
      const raw = 'KEY=foo # this is a comment';
      final result = parser.parse(raw);
      expect(result['KEY'], 'foo');
    });
  });
}
