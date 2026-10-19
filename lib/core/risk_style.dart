import 'package:flutter/material.dart';
import '../features/link_check/domain/link_analyzer.dart';

extension RiskLevelStyle on RiskLevel {
  Color get color => switch (this) {
    RiskLevel.safe => Colors.green,
    RiskLevel.suspicious => Colors.orange,
    RiskLevel.dangerous => Colors.red,
  };

  String get label => switch (this) {
    RiskLevel.safe => 'Looks safe',
    RiskLevel.suspicious => 'Suspicious',
    RiskLevel.dangerous => 'Dangerous',
  };

  IconData get icon => switch (this) {
    RiskLevel.safe => Icons.check_circle,
    RiskLevel.suspicious => Icons.warning_amber_rounded,
    RiskLevel.dangerous => Icons.dangerous,
  };
}