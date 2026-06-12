class GlobalUserMapping {
  final String email;
  final String name;
  final Map<String, dynamic> registeredSchools;

  GlobalUserMapping({
    required this.email,
    required this.name,
    required this.registeredSchools,
  });

  factory GlobalUserMapping.fromMap(Map<String, dynamic> map) {
    return GlobalUserMapping(
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      registeredSchools: Map<String, dynamic>.from(
        map['registered_schools'] ?? {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'registered_schools': registeredSchools,
    };
  }
}
