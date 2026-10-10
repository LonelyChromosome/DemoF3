import 'dart:convert';
import 'dart:io';

import 'package:better_phenikaa_schedule/features/app_update/update_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed fake update verifies and is newer than installed 1.4', () async {
    final bytes = await File('test/fixtures/fake_latest.json').readAsBytes();
    final signature =
        await File('test/fixtures/fake_latest.json.sig').readAsString();
    const publicKey = '7o8anfPOk2nPbSxhQt95+3km1yXx0dOKnKbqZK/uSFA=';
    final manifest = await const UpdateManifestVerifier().verify(
      bytes,
      signature,
      publicKeyBase64: publicKey,
    );
    expect(manifest.versionName, 'cooc.99.99');
    expect(manifest.appliesTo(34), isTrue);
    await expectLater(
      const UpdateManifestVerifier().verify(
        utf8.encode('${utf8.decode(bytes)} '),
        signature,
        publicKeyBase64: publicKey,
      ),
      throwsFormatException,
    );
  });
}
