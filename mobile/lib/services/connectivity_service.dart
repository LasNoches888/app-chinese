import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over connectivity_plus so the rest of the app only deals
/// with a plain bool "online" — used solely to gate the chat feature,
/// which is the one part of the app that needs the network.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
