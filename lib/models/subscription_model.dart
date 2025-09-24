enum SubscriptionStatus {
  purchased,
  pending,
  error,
}

enum SubscriptionPlan {
  assistantMaternelle,
  mam,
  parentEmployeur,
}

class SubscriptionInfo {
  final SubscriptionStatus status;
  final SubscriptionPlan plan;
  final DateTime? purchaseDate;
  final String? productId;

  SubscriptionInfo({
    required this.status,
    required this.plan,
    this.purchaseDate,
    this.productId,
  });

  bool get isActive => status == SubscriptionStatus.purchased;
}
