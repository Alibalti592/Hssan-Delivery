/// The signed-in courier's profile, from `GET /api/auth/me`.
class Courier {
  Courier({
    required this.id,
    required this.name,
    required this.phone,
    required this.roles,
  });

  final int id;
  final String name;
  final String phone;
  final List<String> roles;

  bool get isCourier => roles.contains('ROLE_LIVREUR');

  factory Courier.fromJson(Map<String, dynamic> json) {
    return Courier(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      roles: ((json['roles'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }
}
