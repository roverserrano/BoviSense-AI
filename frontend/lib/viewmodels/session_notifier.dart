import 'package:flutter/foundation.dart';

class SessionNotifier extends ChangeNotifier {
  bool disposed = false;
  @override
  void notifyListeners() {
    if (!disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
