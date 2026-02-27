class User {
  final int id;
  final String name;
  final String username;
  final String role;

  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'],
        username: json['username'],
        role: json['role'],
      );
}
