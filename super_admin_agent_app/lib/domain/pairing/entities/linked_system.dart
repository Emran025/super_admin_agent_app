import 'package:equatable/equatable.dart';

class LinkedSystem extends Equatable {
  final String id;
  final String name;
  final List<String> capabilities;
  final bool isTest;

  const LinkedSystem({
    required this.id,
    required this.name,
    required this.capabilities,
    required this.isTest,
  });

  factory LinkedSystem.fromJson(Map<String, dynamic> json) {
    final rawCaps = json['capabilities'];
    final capabilities = rawCaps is List
        ? List<String>.from(rawCaps.whereType<String>())
        : <String>[];
    return LinkedSystem(
      id: json['id'] as String,
      name: json['name'] as String,
      capabilities: capabilities,
      isTest: json['is_test'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'capabilities': capabilities,
      'is_test': isTest,
    };
  }

  @override
  List<Object?> get props => [id, name, capabilities, isTest];
}
