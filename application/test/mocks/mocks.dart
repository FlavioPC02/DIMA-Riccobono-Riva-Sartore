import 'package:application/core/cubit/profile_cubit.dart';
import 'package:application/core/cubit/settings_cubit.dart';
import 'package:application/services/auth_service.dart';
import 'package:application/services/database_service.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([
  SettingsCubit,
  ProfileCubit,
  AuthService,
  DatabaseService,
])
void main(){}