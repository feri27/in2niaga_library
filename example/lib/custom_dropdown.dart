import 'package:flutter/material.dart';

class CustomDropdown extends StatelessWidget {
  final String labelText;
  final String? hintText;
  final String? value;
  final List<DropdownMenuItem<String>>? items;
  final Function(String? value) onChanged;
  const CustomDropdown({
    Key? key,
    required this.labelText,
    this.hintText,
    required this.value,
    required this.items,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
          label: Text(
            labelText,
            style: const TextStyle(fontSize: 14, color: Colors.black),
          ),
          border: const UnderlineInputBorder()),
      child: DropdownButton<String>(
        isExpanded: true,
        isDense: true,
        value: value,
        underline: const SizedBox.shrink(),
        style: const TextStyle(color: Colors.black),
        items: items,
        hint: hintText != null
            ? Text(
                hintText!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            : null,
        onChanged: onChanged,
      ),
    );
  }
}
