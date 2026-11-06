class Customer {
  final String id;
  String name;
  String phone;
  int visits;
  double totalSpent;
  String lastVisit;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.visits = 0,
    this.totalSpent = 0,
    this.lastVisit = '',
  });

  factory Customer.fromMap(String id, Map<dynamic, dynamic> map) => Customer(
        id: id,
        name: map['name'] ?? '',
        phone: map['phone'] ?? '',
        visits: (map['visits'] as num?)?.toInt() ?? 0,
        totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0,
        lastVisit: map['last_visit'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'visits': visits,
        'total_spent': totalSpent,
        'last_visit': lastVisit,
      };
}
