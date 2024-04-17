class User {
  String id;
  String name;
  bool? totpEnabled;

  User({
    required this.id,
    required this.name,
    this.totpEnabled,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final user = json['data'];
    return User(
        id: user['id'], name: user['name'], totpEnabled: user['totp_url']);
  }
}
