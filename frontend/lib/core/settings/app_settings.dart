import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The selected locale is applied at the MaterialApp level, so every
/// localized screen changes immediately.
final appLocaleProvider = StateProvider<Locale>((ref) => const Locale('en'));
