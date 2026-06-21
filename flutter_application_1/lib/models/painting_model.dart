class Painting {
  final String id;
  final String title;
  final String category;
  final double pricePerM2;
  final String imageUrl;
  final List<String> tags;

  Painting({
    required this.id,
    required this.title,
    required this.category,
    required this.pricePerM2,
    required this.imageUrl,
    this.tags = const [],
  });
}