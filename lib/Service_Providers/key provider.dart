import 'package:flutter/material.dart';
import '../Encryption/Encryption service.dart';

class KeyProvider extends ChangeNotifier {
  bool _hasKeys = false;
  bool _isGenerating = false;

  bool get hasKeys => _hasKeys;
  bool get isGenerating => _isGenerating;

  Future<void> checkKeys() async {
    final publicKey = await E2EEncryptionService.getStoredPublicKeyPem();
    _hasKeys = publicKey != null;
    notifyListeners();
  }

  Future<void> regenerateKeys() async {
    _isGenerating = true;
    notifyListeners();
    try {
      final keyPair = await E2EEncryptionService.generateRSAKeyPair();
      await E2EEncryptionService.storeKeyPair(keyPair);
      _hasKeys = true;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }
}