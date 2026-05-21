import 'package:asr_application/services/streaming/local_agreement_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalAgreementPolicy', () {
    const policy = LocalAgreementPolicy(n: 2);

    group('returns null', () {
      test('when history is empty', () {
        expect(policy.confirmedPrefix([]), isNull);
      });

      test('when history has fewer than n entries', () {
        expect(policy.confirmedPrefix(['hello world']), isNull);
      });

      test('when transcripts share no full word', () {
        expect(
          policy.confirmedPrefix(['alpha beta', 'gamma delta']),
          isNull,
        );
      });

      test('when shared prefix is a partial word', () {
        // 'hell' ends mid-word in 'hello world', no full word confirmed
        expect(
          policy.confirmedPrefix(['hell', 'hello world']),
          isNull,
        );
      });

      test('when transcripts are completely different', () {
        expect(policy.confirmedPrefix(['foo bar', 'baz qux']), isNull);
      });
    });

    group('confirms a prefix', () {
      test('when two transcripts share a full leading word', () {
        expect(
          policy.confirmedPrefix(['hello world', 'hello world today']),
          'hello world',
        );
      });

      test('when two transcripts share multiple words', () {
        expect(
          policy.confirmedPrefix([
            'the quick brown fox',
            'the quick brown fox jumps',
          ]),
          'the quick brown fox',
        );
      });

      test('uses only the last n entries from a longer history', () {
        // first entry disagrees but last 2 agree, so confirmation is expected
        expect(
          policy.confirmedPrefix([
            'completely different',
            'hello world today',
            'hello world now',
          ]),
          'hello world',
        );
      });

      test('confirms longest shared word boundary', () {
        expect(
          policy.confirmedPrefix([
            'one two three four',
            'one two three four five',
          ]),
          'one two three four',
        );
      });

      test('confirms a single complete word', () {
        expect(policy.confirmedPrefix(['hello', 'hello']), 'hello');
      });
    });

    group('n=3 policy', () {
      const policy3 = LocalAgreementPolicy(n: 3);

      test('requires three agreeing transcripts', () {
        expect(
          policy3.confirmedPrefix(['hello world', 'hello world today']),
          isNull,
        );
        expect(
          policy3.confirmedPrefix([
            'hello world',
            'hello world today',
            'hello world now',
          ]),
          'hello world',
        );
      });
    });

    group('edge cases', () {
      test('strips leading whitespace from confirmed prefix', () {
        expect(
          policy.confirmedPrefix(['  hello world', '  hello world today']),
          'hello world',
        );
      });

      test('empty transcripts produce no confirmation', () {
        expect(policy.confirmedPrefix(['', '']), isNull);
      });
    });
  });
}
