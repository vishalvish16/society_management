import 'package:image_picker/image_picker.dart';

/// Opens the device camera and returns the captured image, or null if cancelled.
Future<XFile?> pickPhotoFromCamera({
  ImagePicker? imagePicker,
  int imageQuality = 70,
  double maxWidth = 1600,
  double maxHeight = 1600,
}) async {
  final picker = imagePicker ?? ImagePicker();
  return picker.pickImage(
    source: ImageSource.camera,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    preferredCameraDevice: CameraDevice.rear,
  );
}
