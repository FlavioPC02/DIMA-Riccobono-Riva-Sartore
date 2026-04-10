import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mockito/mockito.dart';

class MockStorage extends Mock implements Storage {}

void setupTest() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HydratedBloc.storage = MockStorage();
}