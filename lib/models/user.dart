class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.area,
    this.paymentQrUrl,
    this.banned = false,
    this.createdAt,
  });

  final int id;
  final String email, name;
  final String role; // buyer | seller | admin
  final String? area, paymentQrUrl, createdAt;
  final bool banned;

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as int,
        email: (j['email'] ?? '') as String,
        name: j['name'] as String,
        role: j['role'] as String,
        area: j['area'] as String?,
        paymentQrUrl: j['payment_qr_url'] as String?,
        banned: (j['banned'] ?? false) as bool,
        createdAt: j['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role,
        'area': area,
        'payment_qr_url': paymentQrUrl,
        'banned': banned,
        'created_at': createdAt,
      };

  User withRole(String r) => User(
      id: id, email: email, name: name, role: r, area: area,
      paymentQrUrl: paymentQrUrl, banned: banned, createdAt: createdAt);
}

class UserSummary {
  const UserSummary({required this.id, required this.name, this.area});
  final int id;
  final String name;
  final String? area;

  factory UserSummary.fromJson(Map<String, dynamic> j) => UserSummary(
      id: j['id'] as int, name: j['name'] as String, area: j['area'] as String?);
}
