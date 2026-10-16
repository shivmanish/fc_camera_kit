import '../../utils/fc_result.dart';
import 'fc_photo_metadata.dart';

/// Resolves the who / when / where at capture time; `null` means none.
typedef FcMetadataResolver = Future<FcResult<FcPhotoMetadata?>> Function();
