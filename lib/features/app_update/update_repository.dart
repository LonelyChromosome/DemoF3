import 'dart:convert';

import 'package:better_phenikaa_schedule/features/app_update/update_manifest.dart';
import 'package:better_phenikaa_schedule/features/app_update/update_http_stub.dart'
    if (dart.library.io) 'update_http_io.dart'
    as transport;

final class UpdateRepository {
  UpdateRepository({UpdateManifestVerifier? verifier})
    : _verifier = verifier ?? const UpdateManifestVerifier();
  final UpdateManifestVerifier _verifier;

  Future<UpdateManifest> fetch() async {
    final uri = Uri.tryParse(updateManifestUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        updatePublicKeyBase64.isEmpty) {
      throw const FormatException('Update channel is not configured');
    }
    final bytes = await transport.fetchUpdateBytes(uri, 8192);
    final signature = await transport.fetchUpdateBytes(
      Uri.parse('${uri.toString()}.sig'),
      256,
    );
    return _verifier.verify(bytes, ascii.decode(signature));
  }
}
