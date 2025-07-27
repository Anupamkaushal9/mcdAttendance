class ColorSchema {
  final String body;
  final String footer;
  final String header;

  ColorSchema({
    required this.body,
    required this.footer,
    required this.header,
  });

  factory ColorSchema.fromJson(Map<String, dynamic> json) {
    return ColorSchema(
      body: json['body'] ?? '',
      footer: json['footer'] ?? '',
      header: json['header'] ?? '',
    );
  }
}