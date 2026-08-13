
class Base {
  T track<T>(T t) => t;
}
class Derived extends Base {
  late final int a = track(1);
}
void main() {
  print(Derived().a);
}
