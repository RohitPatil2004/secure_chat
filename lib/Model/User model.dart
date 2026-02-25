class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? publicKey;
  final DateTime? lastSeen;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.publicKey,
    this.lastSeen,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'],
      publicKey: map['publicKey'],
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as dynamic).toDate()
          : null,
    );
  }
}