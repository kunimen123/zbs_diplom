class User {
  final int id;
  final String username;
  final String? email;
  final bool isStaff;   // пригодится, чтобы показывать админку только персоналу

  User({
    required this.id,
    required this.username,
    this.email,
    this.isStaff = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      isStaff: json['is_staff'] ?? false,
    );
  }
}