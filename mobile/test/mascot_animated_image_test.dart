import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/components/mascot_animated_image.dart';

void main() {
  group('sampleMascotMotion', () {
    test('every motion starts and ends at rest', () {
      for (final motion in MascotMotion.values) {
        for (final pose in [
          sampleMascotMotion(motion, 0),
          sampleMascotMotion(motion, 1),
        ]) {
          expect(pose.translateFraction, Offset.zero);
          expect(pose.scaleX, 1);
          expect(pose.scaleY, 1);
          expect(pose.rotation, 0);
        }
      }
    });

    test('the correct-answer jump moves the mascot upward mid-flight', () {
      final pose = sampleMascotMotion(MascotMotion.correct, 0.4);
      expect(pose.translateFraction.dy, lessThan(0));
    });

    test('the incorrect-answer stumble displaces sideways mid-flight', () {
      final pose = sampleMascotMotion(MascotMotion.incorrect, 0.25);
      expect(pose.translateFraction.dx, isNot(0));
    });
  });
}
