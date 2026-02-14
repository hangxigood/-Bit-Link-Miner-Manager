class DataColumnConfig {
  final String id;
  final String label;
  final bool visible;
  final double width;

  const DataColumnConfig({
    required this.id,
    required this.label,
    required this.visible,
    required this.width,
  });

  DataColumnConfig copyWith({String? id, String? label, bool? visible, double? width}) {
    return DataColumnConfig(
      id: id ?? this.id,
      label: label ?? this.label,
      visible: visible ?? this.visible,
      width: width ?? this.width,
    );
  }
}
