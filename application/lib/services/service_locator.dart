import 'package:application/core/cubit/location_cubit.dart';
import 'package:application/core/repository/location_repository.dart';
import 'package:get_it/get_it.dart';

final GetIt sl = GetIt.instance;

Future<void> setupLocator() async {

  //Repository
  final repo = HiveLocationRepository();
  await repo.init();
  sl.registerSingleton<ILocationRepository>(repo);

  //Cubits
  sl.registerFactory<LocationCubit>(
    () => LocationCubit(sl<ILocationRepository>()),
  );
}