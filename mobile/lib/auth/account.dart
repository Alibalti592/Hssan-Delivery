/// The signed-in account's profile, from `GET /api/auth/me`. Shared by both
/// personas this app serves: clients (ROLE_CLIENT) and couriers
/// (ROLE_LIVREUR).
class Account {
  Account({
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
  bool get isClient => roles.contains('ROLE_CLIENT');

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      roles: ((json['roles'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }
}
