class Kullanici {
  const Kullanici({required this.id, required this.email, required this.ad, required this.rol});

  final int id;
  final String email;
  final String ad;
  final String rol;

  bool get yoneticiMi => rol == 'admin';

  factory Kullanici.fromJson(Map<String, dynamic> json) => Kullanici(
        id: json['id'] as int,
        email: json['email'] as String,
        ad: json['display_name'] as String,
        rol: json['role'] as String,
      );
}
