import 'package:flutter_test/flutter_test.dart';
import 'package:myfit_tracker/main.dart';

void main() {
  test('uses the reference design tokens', () {
    expect(green.value, 0xff24e88a);
    expect(background.value, 0xff0e1113);
  });
}
