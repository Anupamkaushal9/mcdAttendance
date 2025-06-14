import 'package:flutter/cupertino.dart';
import 'package:motion_tab_bar/MotionTabBarController.dart';

class BottomNavigationProvider with ChangeNotifier {
  int _currentIndex = 0;
  MotionTabBarController? _tabController;

  int get currentIndex => _currentIndex;
  MotionTabBarController? get tabController => _tabController;

  set currentIndex(int index) {
    _currentIndex = index;
    _tabController?.index = index; // Sync with MotionTabBarController
    notifyListeners();
  }

  void setTabController(MotionTabBarController controller) {
    _tabController = controller;
  }
}