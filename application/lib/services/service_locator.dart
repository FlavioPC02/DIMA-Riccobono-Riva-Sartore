import 'package:application/core/cubit/location_cubit.dart';
import 'package:application/core/repository/location_repository.dart';
import 'package:application/services/phone_wear_sync.dart';
import 'package:get_it/get_it.dart';

final GetIt sl = GetIt.instance;

Future<void> setupLocator() async {

  //Repository
  final repo = HiveLocationRepository();
  await repo.init();
  sl.registerSingleton<ILocationRepository>(repo);

  // Wear sync service
  final wearSync = PhoneWearSyncService();
  wearSync.initialize();

  sl.registerSingleton<PhoneWearSyncService>(
    wearSync,
  );

  //Cubits
  sl.registerFactory<LocationCubit>(
    () => LocationCubit(sl<ILocationRepository>()),
  );
}