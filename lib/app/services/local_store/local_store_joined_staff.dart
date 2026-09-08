class LocalStoreJoinedStaff {
  const LocalStoreJoinedStaff({
    required this.deviceId,
    required this.displayName,
    required this.joinMethod,
    required this.joinedAt,
    this.userId,
    this.platform,
    this.remoteAddress,
  });

  final String deviceId;
  final String displayName;
  final String joinMethod; // code | qr
  final DateTime joinedAt;
  final String? userId;
  final String? platform;
  final String? remoteAddress;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'displayName': displayName,
        'joinMethod': joinMethod,
        'joinedAt': joinedAt.toIso8601String(),
        if (userId != null) 'userId': userId,
        if (platform != null) 'platform': platform,
        if (remoteAddress != null) 'remoteAddress': remoteAddress,
      };

  factory LocalStoreJoinedStaff.fromJson(Map<String, dynamic> json) {
    return LocalStoreJoinedStaff(
      deviceId: json['deviceId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Staff',
      joinMethod: json['joinMethod']?.toString() ?? 'code',
      joinedAt: DateTime.tryParse(json['joinedAt']?.toString() ?? '') ??
          DateTime.now(),
      userId: json['userId']?.toString(),
      platform: json['platform']?.toString(),
      remoteAddress: json['remoteAddress']?.toString(),
    );
  }

  LocalStoreJoinedStaff copyWith({
    String? displayName,
    String? joinMethod,
    DateTime? joinedAt,
    String? userId,
    String? platform,
    String? remoteAddress,
  }) {
    return LocalStoreJoinedStaff(
      deviceId: deviceId,
      displayName: displayName ?? this.displayName,
      joinMethod: joinMethod ?? this.joinMethod,
      joinedAt: joinedAt ?? this.joinedAt,
      userId: userId ?? this.userId,
      platform: platform ?? this.platform,
      remoteAddress: remoteAddress ?? this.remoteAddress,
    );
  }
}
