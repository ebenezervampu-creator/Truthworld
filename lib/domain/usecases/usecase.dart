import 'package:truthworld/core/network/result.dart';

/// Base contract for an asynchronous use case requiring parameters [Params].
/// Adheres to Uncle Bob's Clean Architecture standards, decoupling presentation
/// controllers from concrete repository and data source implementations.
abstract class UseCase<Type, Params> {
  const UseCase();
  Future<Result<Type>> call(Params params);
}

/// Base contract for an asynchronous use case requiring no parameters.
abstract class NoParamsUseCase<Type> {
  const NoParamsUseCase();
  Future<Result<Type>> call();
}

/// Parameter placeholder when no parameters are required.
class NoParams {
  const NoParams();
}
