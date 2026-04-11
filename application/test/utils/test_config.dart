import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

class MockStorage implements Storage {
  final Map<String, dynamic> _box = {};

  @override
  Future<void> write(String key, dynamic value) async {
    _box[key] = value;
  }

  @override
  dynamic read(String key) => _box[key];

  @override
  Future<void> delete(String key) async {
    _box.remove(key);
  }

  @override
  Future<void> clear() async {
    _box.clear();
  }

  @override
  Future<void> close() async {}
}

void setupTest() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HydratedBloc.storage = MockStorage();
}