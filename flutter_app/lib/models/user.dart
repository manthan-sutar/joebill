class User {
  final int id;
  final String name;
  final String username;
  final String role;
  final bool mustChangePassword;

  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.mustChangePassword = false,
  });

  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'],
        username: json['username'],
        role: json['role'],
        mustChangePassword: json['must_change_password'] == true,
      );

  User copyWith({
    int? id,
    String? name,
    String? username,
    String? role,
    bool? mustChangePassword,
  }) =>
      User(
        id: id ?? this.id,
        name: name ?? this.name,
        username: username ?? this.username,
        role: role ?? this.role,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      );
}
