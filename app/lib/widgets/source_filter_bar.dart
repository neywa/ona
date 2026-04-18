import 'package:flutter/material.dart';

class SourceFilterBar extends StatelessWidget {
  final List<String> sources;
  final String? selectedSource;
  final ValueChanged<String?> onSourceSelected;

  const SourceFilterBar({
    super.key,
    required this.sources,
    required this.selectedSource,
    required this.onSourceSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: const Text('All'),
                selected: selectedSource == null,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onSourceSelected(null),
              ),
            ),
            for (final source in sources)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(source),
                  selected: selectedSource == source,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onSourceSelected(source),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
