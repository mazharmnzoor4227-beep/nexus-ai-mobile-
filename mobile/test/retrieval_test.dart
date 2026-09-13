import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_ai/core/retrieval.dart';
import 'package:nexus_ai/core/gateway.dart';

void main() {
  test('cosine ranks aligned and orthogonal vectors correctly', () {
    expect(cosine([1, 0], [2, 0]), 1);
    expect(cosine([1, 0], [0, 1]), 0);
    expect(cosine([0, 0], [1, 1]), 0);
    expect(() => cosine([1], [1, 2]), throwsA(isA<ApiError>()));
  });
}
