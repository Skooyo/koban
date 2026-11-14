import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:koban/app/app_services.dart';

void main() {
  test(
    'the app turns on the Android photo picker for every Android version',
    () {
      final previous = ImagePickerPlatform.instance;
      addTearDown(() => ImagePickerPlatform.instance = previous);
      final android = ImagePickerAndroid();
      ImagePickerPlatform.instance = android;
      expect(android.useAndroidPhotoPicker, isFalse);

      useAndroidPhotoPicker();

      expect(android.useAndroidPhotoPicker, isTrue);
    },
  );
}
