import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which screen is active in the center content area.
final activeScreenProvider = StateProvider<int>((ref) => 0);
