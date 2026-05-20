import 'package:get/get.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart';

class SearchBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SearchController>(() => SearchController());
  }
}
