class RiderModel {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final String gender;
  final String profileImageUrl;
  final String vehicleType;
  final String vehicleNumber;
  final Map<String, dynamic> documents;
  final String emergencyContact;
  final bool isOnline;
  final bool isVerified;
  final String verificationStatus; // 'pending' | 'approved' | 'rejected'
  final bool isBlocked;
  final double rating;
  final int totalRides;
  final String createdAt;
  final String role;

  RiderModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.email = '',
    this.gender = 'Female',
    this.profileImageUrl = '',
    this.vehicleType = 'Bike / Scooter',
    required this.vehicleNumber,
    this.documents = const {},
    this.emergencyContact = '',
    this.isOnline = false,
    this.isVerified = false,
    this.verificationStatus = 'pending',
    this.isBlocked = false,
    this.rating = 5.0,
    this.totalRides = 0,
    String? createdAt,
    this.role = 'rider',
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'email': email,
      'gender': gender,
      'profileImageUrl': profileImageUrl,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'documents': documents,
      'emergencyContact': emergencyContact,
      'isOnline': isOnline,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
      'isBlocked': isBlocked,
      'rating': rating,
      'totalRides': totalRides,
      'createdAt': createdAt,
      'role': role,
    };
  }

  factory RiderModel.fromMap(Map<dynamic, dynamic> map, {String? uid}) {
    final status = (map['verificationStatus'] ?? (map['isVerified'] == true ? 'approved' : 'pending')).toString();
    return RiderModel(
      uid: (map['uid'] ?? uid ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      gender: (map['gender'] ?? 'Female').toString(),
      profileImageUrl: (map['profileImageUrl'] ?? '').toString(),
      vehicleType: (map['vehicleType'] ?? 'Bike / Scooter').toString(),
      vehicleNumber: (map['vehicleNumber'] ?? '').toString(),
      documents: map['documents'] != null ? Map<String, dynamic>.from(map['documents'] as Map) : {},
      emergencyContact: (map['emergencyContact'] ?? '').toString(),
      isOnline: map['isOnline'] == true || map['isOnline'] == 1,
      isVerified: map['isVerified'] == true || map['isVerified'] == 1 || status == 'approved',
      verificationStatus: status,
      isBlocked: map['isBlocked'] == true || map['isBlocked'] == 1,
      rating: double.tryParse(map['rating']?.toString() ?? '5.0') ?? 5.0,
      totalRides: int.tryParse(map['totalRides']?.toString() ?? '0') ?? 0,
      createdAt: (map['createdAt'] ?? '').toString(),
      role: (map['role'] ?? 'rider').toString(),
    );
  }

  RiderModel copyWith({
    String? uid,
    String? name,
    String? phone,
    String? email,
    String? gender,
    String? profileImageUrl,
    String? vehicleType,
    String? vehicleNumber,
    Map<String, dynamic>? documents,
    String? emergencyContact,
    bool? isOnline,
    bool? isVerified,
    String? verificationStatus,
    bool? isBlocked,
    double? rating,
    int? totalRides,
    String? createdAt,
    String? role,
  }) {
    return RiderModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      documents: documents ?? this.documents,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isBlocked: isBlocked ?? this.isBlocked,
      rating: rating ?? this.rating,
      totalRides: totalRides ?? this.totalRides,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
    );
  }
}
