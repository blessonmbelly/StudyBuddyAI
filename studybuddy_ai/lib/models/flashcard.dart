class FlashcardModel {
  final String id;
  final String front;
  final String back;
  final String? hint;
  final int orderIndex;
  final String status; // 'unreviewed', 'known', 'learning'
  final int reviewCount;
  final DateTime? lastReviewedAt;

  FlashcardModel({
    required this.id,
    required this.front,
    required this.back,
    this.hint,
    this.orderIndex = 0,
    this.status = 'unreviewed',
    this.reviewCount = 0,
    this.lastReviewedAt,
  });

  bool get isKnown => status == 'known';
  bool get isLearning => status == 'learning';
  bool get isUnreviewed => status == 'unreviewed';

  factory FlashcardModel.fromJson(Map<String, dynamic> json) {
    return FlashcardModel(
      id: json['id'] as String? ?? '',
      front: json['front'] as String? ?? '',
      back: json['back'] as String? ?? '',
      hint: json['hint'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
      status: json['status'] as String? ?? 'unreviewed',
      reviewCount: json['review_count'] as int? ?? 0,
      lastReviewedAt: json['last_reviewed_at'] != null
          ? DateTime.tryParse(json['last_reviewed_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'front': front,
      'back': back,
      'hint': hint,
      'order_index': orderIndex,
      'status': status,
      'review_count': reviewCount,
      'last_reviewed_at': lastReviewedAt?.toIso8601String(),
    };
  }

  FlashcardModel copyWith({
    String? id,
    String? front,
    String? back,
    String? hint,
    int? orderIndex,
    String? status,
    int? reviewCount,
    DateTime? lastReviewedAt,
  }) {
    return FlashcardModel(
      id: id ?? this.id,
      front: front ?? this.front,
      back: back ?? this.back,
      hint: hint ?? this.hint,
      orderIndex: orderIndex ?? this.orderIndex,
      status: status ?? this.status,
      reviewCount: reviewCount ?? this.reviewCount,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }
}

class FlashcardDeck {
  final String id;
  final String title;
  final String subject;
  final String? description;
  final int cardCount;
  final int masteredCount;
  final String? documentId;
  final String? noteId;
  final List<FlashcardModel> cards;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FlashcardDeck({
    required this.id,
    required this.title,
    required this.subject,
    this.description,
    this.cardCount = 0,
    this.masteredCount = 0,
    this.documentId,
    this.noteId,
    this.cards = const [],
    this.createdAt,
    this.updatedAt,
  });

  double get masteryPercent {
    if (cardCount <= 0) return 0.0;
    return (masteredCount / cardCount).clamp(0.0, 1.0);
  }

  int get masteryPercentageInt => (masteryPercent * 100).round();

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'] as List<dynamic>? ?? [];
    return FlashcardDeck(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Study Deck',
      subject: json['subject'] as String? ?? 'General',
      description: json['description'] as String?,
      cardCount: json['card_count'] as int? ?? rawCards.length,
      masteredCount: json['mastered_count'] as int? ?? 0,
      documentId: json['document_id'] as String?,
      noteId: json['note_id'] as String?,
      cards: rawCards
          .map((c) => FlashcardModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'description': description,
      'card_count': cardCount,
      'mastered_count': masteredCount,
      'document_id': documentId,
      'note_id': noteId,
      'cards': cards.map((c) => c.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  FlashcardDeck copyWith({
    String? id,
    String? title,
    String? subject,
    String? description,
    int? cardCount,
    int? masteredCount,
    String? documentId,
    String? noteId,
    List<FlashcardModel>? cards,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FlashcardDeck(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      cardCount: cardCount ?? this.cardCount,
      masteredCount: masteredCount ?? this.masteredCount,
      documentId: documentId ?? this.documentId,
      noteId: noteId ?? this.noteId,
      cards: cards ?? this.cards,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

