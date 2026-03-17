class Rate {
  final String uid;
  final String subject;
  final String body;
  final double stars;

  const Rate({
    required this.uid,
    required this.subject,
    required this.body,
    required this.stars,
  });

  factory Rate.fromMap(Map<String, dynamic> data) {
    final rawStars = data['stars'];

    return Rate(
      body: data['body']?.toString() ?? '',
      stars: rawStars is num ? rawStars.toDouble() : 0.0,
      subject: data['subject']?.toString() ?? '',
      uid: data['uid']?.toString() ?? '',
    );
  }
}
