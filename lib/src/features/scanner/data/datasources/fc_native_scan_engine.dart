import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/fc_scan_options.dart';
import '../../../../core/error/fc_camera_exception.dart';
import '../../../../core/permissions/fc_permission_type.dart';
import '../../../../core/permissions/fc_permissions.dart';
import 'fc_scan_engine.dart';

/// ML Kit Document Scanner on Android, VisionKit on iOS.
final class FcNativeScanEngine implements FcScanEngine {
  FcNativeScanEngine({FcPermissions? permissions})
    : _permissions = permissions ?? FcPermissions.instance;

  final FcPermissions _permissions;

  @override
  Future<List<String>?> scan(FcScanOptions options) async {
    try {
      return await CunningDocumentScanner.getPictures(
        noOfPages: options.maxPages,
        scannerSource: _sourceOf(options.source),
        androidScannerMode: _modeOf(options.enhancement),
        // iOS defaults to PNG; JPEG keeps memory and the compressor's work down.
        iosScannerOptions: IosScannerOptions(
          imageFormat: IosImageFormat.jpg,
          showFilterBar: options.enhancement != FcScanEnhancement.basic,
        ),
      );
    } on CunningDocumentScannerException catch (error, stackTrace) {
      if (error.code == 'permission_denied') {
        throw PermissionException(
          'Camera access was not granted.',
          permanentlyDenied: await _cameraNeedsSettings(),
          cause: error,
          stackTrace: stackTrace,
        );
      }
      throw CameraException(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    } on PlatformException catch (error, stackTrace) {
      throw CameraException(
        error.message ?? 'The document scanner failed.',
        cause: error,
        stackTrace: stackTrace,
      );
    } on MissingPluginException catch (error, stackTrace) {
      throw CameraException(
        'The document scanner is not available on this platform.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      await CunningDocumentScanner.cleanCache();
    } catch (_) {
      // Best effort; a stale cache file must never fail a finished scan.
    }
  }

  Future<bool> _cameraNeedsSettings() async {
    try {
      return (await _permissions.statusOf(
        FcPermissionType.camera,
      )).needsAppSettings;
    } catch (_) {
      return false;
    }
  }

  static ScannerSource _sourceOf(FcScanSource source) => switch (source) {
    FcScanSource.camera => ScannerSource.camera,
    FcScanSource.gallery => ScannerSource.gallery,
    FcScanSource.cameraAndGallery => ScannerSource.cameraAndGallery,
  };

  static AndroidScannerMode _modeOf(FcScanEnhancement enhancement) =>
      switch (enhancement) {
        FcScanEnhancement.basic => AndroidScannerMode.base,
        FcScanEnhancement.filters => AndroidScannerMode.baseWithFilter,
        FcScanEnhancement.full => AndroidScannerMode.full,
      };
}
