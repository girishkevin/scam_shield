import 'package:flutter/material.dart';
import '../features/link_check/domain/link_analyzer.dart';
import 'app_theme.dart';

extension RiskLevelStyle on RiskLevel {
  Color get color => switch (this) {
    RiskLevel.safe => AppColors.safe,
    RiskLevel.suspicious => AppColors.caution,
    RiskLevel.dangerous => AppColors.danger,
  };

  String get label => switch (this) {
    RiskLevel.safe => 'Looks safe',
    RiskLevel.suspicious => 'Be careful',
    RiskLevel.dangerous => 'Dangerous',
  };

  IconData get icon => switch (this) {
    RiskLevel.safe => Icons.verified_rounded,
    RiskLevel.suspicious => Icons.error_outline_rounded,
    RiskLevel.dangerous => Icons.gpp_bad_rounded,
  };
}