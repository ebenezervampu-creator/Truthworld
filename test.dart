
class Base {
  T track<T>(T t) => t;
}
class Derived extends Base {
  late final a = track(1);
}
void main() {
  print(Derived().a);
}
