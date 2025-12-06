import 'package:flutter/material.dart';
import 'package:smartpay/core/validators/form_validators.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final bool showText;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final strength = FormValidators.checkPasswordStrength(password);

    Color color;
    String text;
    double progress;

    switch (strength) {
      case PasswordStrength.empty:
        color = Colors.grey[300]!;
        text = 'Enter password';
        progress = 0.0;
        break;
      case PasswordStrength.weak:
        color = Colors.red[400]!;
        text = 'Weak password';
        progress = 0.33;
        break;
      case PasswordStrength.medium:
        color = Colors.orange[400]!;
        text = 'Medium strength';
        progress = 0.66;
        break;
      case PasswordStrength.strong:
        color = Colors.green[400]!;
        text = 'Strong password';
        progress = 1.0;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                color: color,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (showText && password.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  text.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (showText && password.isEmpty)
          const SizedBox(height: 4)
        else if (showText)
          const SizedBox(height: 8),
        if (showText && password.isNotEmpty)
          Text(
            _getPasswordTips(password, strength),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
      ],
    );
  }

  String _getPasswordTips(String password, PasswordStrength strength) {
    if (strength == PasswordStrength.strong) return '✓ Excellent password!';

    final tips = <String>[];

    if (password.length < 8) {
      tips.add('at least 8 characters');
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      tips.add('one uppercase letter');
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      tips.add('one lowercase letter');
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      tips.add('one number');
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      tips.add('one special character');
    }

    if (tips.isEmpty) return '';

    final prefix =
        strength == PasswordStrength.weak ? 'Add ' : 'Stronger with ';

    if (tips.length == 1) {
      return '$prefix${tips.first}';
    } else if (tips.length == 2) {
      return '$prefix${tips.first} and ${tips.last}';
    } else {
      final allButLast = tips.sublist(0, tips.length - 1).join(', ');
      return '$prefix$allButLast, and ${tips.last}';
    }
  }
}
