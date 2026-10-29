class FontaAppsPath {
  FontaAppsPath._();
  static final FontaAppsPath instance = FontaAppsPath._();
  factory FontaAppsPath() => instance;

  static String undefinedPath = 'Undefined';

  /// List of active route
  final List<String> _paths = [];

  /// Get root of active route path
  String root() => _paths.first;

  /// Get current active route path
  String now() => isEmpty() ? undefinedPath : _paths.last;

  /// Clear all active route
  flush() {
    _paths.clear();
  }

  /// Check if there is an active route
  bool isEmpty() => _paths.isEmpty;

  /// Get total active route
  int depth() => _paths.length;

  /// Check if route is active
  bool hasPath(String path) => _paths.contains(path);

  /// Return true if `path` is before the current path
  bool isPathBefore(String path) =>
      _paths.length > 1 && (position(now()) - 1) == position(path);

  /// Get path position
  int position(String path) => _paths.lastIndexOf(path);

  /// Get all active route
  List<String> getPaths() => _paths;

  push(String? path) {
    String path0 = cleanPath(path);
    _paths.add(path0);
  }

  /// Remove current route path from path list
  String pop() => _paths.removeLast();

  /// Remove route path from path list until target path
  bool popUntil(String path) {
    bool isSuccess = false;
    if (hasPath(path)) {
      int idx = position(path);
      if (idx != -1) {
        _paths.removeRange(idx + 1, _paths.length);

        isSuccess = true;
      }
    }

    return isSuccess;
  }

  /// Remove route path from path list until target path,
  /// then add new route path to list
  bool popUntilThenPush(String path, String newPath) {
    bool isSuccess = popUntil(path);
    if (isSuccess) push(newPath);
    return isSuccess;
  }

  void replace(String path) {
    if (_paths.isNotEmpty) {
      _paths.last = path;
    } else {
      push(path);
    }
  }

  String cleanPath(String? path) {
    String path0 = path ?? undefinedPath;
    if (path0.contains('@')) {
      path0 = path0.split('@').first;
    }
    if (path0.length > 1 && path0.endsWith('/')) {
      path0 = path0.substring(0, path0.length - 1);
    }
    return path0;
  }
}
