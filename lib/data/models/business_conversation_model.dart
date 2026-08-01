class BusinessConversationModel {
  const BusinessConversationModel({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.businessImage,
    required this.customerId,
    required this.customerName,
    required this.ownerId,
    required this.isOwner,
    required this.lastMessage,
    required this.unreadCount,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String businessImage;
  final String customerId;
  final String customerName;
  final String ownerId;
  final bool isOwner;
  final String lastMessage;
  final int unreadCount;

  factory BusinessConversationModel.fromJson(Map<String, dynamic> json) {
    return BusinessConversationModel(
      id: (json['id'] ?? '').toString(),
      businessId: (json['businessId'] ?? '').toString(),
      businessName: (json['businessName'] ?? '').toString(),
      businessImage: (json['businessImage'] ?? '').toString(),
      customerId: (json['customerId'] ?? '').toString(),
      customerName: (json['customerName'] ?? '').toString(),
      ownerId: (json['ownerId'] ?? '').toString(),
      isOwner: json['isOwner'] == true,
      lastMessage: (json['lastMessage'] ?? '').toString(),
      unreadCount: int.tryParse((json['unreadCount'] ?? 0).toString()) ?? 0,
    );
  }
}
