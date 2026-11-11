List<String> healthConditions(dynamic raw) {
  final values = raw is List ? raw : [if (raw != null) raw];
  return values
      .map((v) => '$v'.trim())
      .where((v) => v.isNotEmpty && v.toLowerCase() != 'none')
      .toSet()
      .toList();
}
