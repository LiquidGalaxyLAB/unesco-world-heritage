import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

class LGTextField extends StatelessWidget {
  const LGTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.validator,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: AppColors.onSurface,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        filled: false,
        constraints: const BoxConstraints(minHeight: 66),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        hintStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        labelStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 18, right: 22),
          child: Icon(icon, color: AppColors.onSurfaceVariant, size: 28),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 78),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
