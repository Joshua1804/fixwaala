import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/core/models/provider_public_profile.dart';
import 'package:fixwaala/features/provider_search/services/provider_search_service.dart';

ProviderPublicProfile _provider(
  String id,
  String name, {
  List<ServiceCategory> skills = const [],
}) {
  return ProviderPublicProfile(
    id: id,
    name: name,
    isVerified: false,
    createdAt: DateTime(2026, 1, 1),
    skills: skills,
  );
}

void main() {
  final providers = [
    _provider('1', 'Ramesh Kumar', skills: [ServiceCategory.plumber]),
    _provider('2', 'Anita Sharma', skills: [ServiceCategory.electrician]),
    _provider('3', 'Ravi Plumber', skills: [ServiceCategory.plumber]),
  ];

  test('empty query returns nothing', () {
    expect(matchProviders(providers, ''), isEmpty);
    expect(matchProviders(providers, '   '), isEmpty);
  });

  test('category-name query returns everyone with that skill', () {
    final result = matchProviders(providers, 'plumber');
    expect(result.map((p) => p.id), containsAll(['1', '3']));
    expect(result.map((p) => p.id), isNot(contains('2')));
  });

  test('category query is case-insensitive', () {
    final result = matchProviders(providers, 'PLUMBER');
    expect(result.map((p) => p.id), containsAll(['1', '3']));
  });

  test('name query returns providers whose name contains it', () {
    final result = matchProviders(providers, 'ramesh');
    expect(result.map((p) => p.id), ['1']);
  });

  test('a name that also happens to contain a category word still name-matches', () {
    final result = matchProviders(providers, 'ravi');
    expect(result.map((p) => p.id), ['3']);
  });
}
