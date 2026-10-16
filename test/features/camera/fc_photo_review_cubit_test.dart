import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:fc_camera_kit/src/features/camera/presentation/cubits/fc_photo_review/fc_photo_review_cubit.dart';
import 'package:fc_camera_kit/src/features/camera/presentation/cubits/fc_photo_review/fc_photo_review_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('fc_review_'));
  tearDown(() => dir.deleteSync(recursive: true));

  XFile shot(String name) =>
      XFile((File('${dir.path}/$name.jpg')..writeAsBytesSync([1, 2, 3])).path);

  test('starts live, with nothing to review', () async {
    final cubit = FcPhotoReviewCubit();

    expect(cubit.state, isNull);
    await cubit.close();
  });

  test('retake deletes the shot and goes back to live', () async {
    final cubit = FcPhotoReviewCubit();
    final photo = shot('a');

    cubit.review(photo);
    expect(cubit.state, FcPhotoReview(photo: photo));

    await cubit.retake();
    expect(cubit.state, isNull);
    expect(File(photo.path).existsSync(), isFalse);
    await cubit.close();
  });

  test('leaving without using the shot deletes it', () async {
    final cubit = FcPhotoReviewCubit();
    final photo = shot('b');

    cubit.review(photo);
    await cubit.close();

    expect(File(photo.path).existsSync(), isFalse);
  });

  test('an accepted shot is handed over and kept', () async {
    final cubit = FcPhotoReviewCubit();
    final photo = shot('c');

    cubit.review(photo);
    expect(cubit.accept(), FcReviewedPhoto(photo));
    await cubit.close();

    expect(File(photo.path).existsSync(), isTrue);
  });
}
