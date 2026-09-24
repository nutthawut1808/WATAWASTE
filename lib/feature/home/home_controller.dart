import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class HomeController extends GetxController {
  final DealRepo dealRepo;

  HomeController({required this.dealRepo});

  final deals = <DealModel>[].obs;
  final flashDeals = <DealModel>[].obs;
  final isLoading = true.obs;
  final todayOnly = false.obs;
  final scrollOffset = 0.0.obs;

  final scrollController = ScrollController();
  final refreshController = RefreshController();

  int _page = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;
  int _fetchVersion = 0; // นับเวอร์ชันเพื่อป้องกัน Race Condition

  bool get hasMore => _page < _totalPages;

  List<DealModel> get visibleDeals => todayOnly.value
      ? deals.where((d) => d.pickupWindow.isToday).toList()
      : deals.toList();

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _initialLoad();
  }

  void _onScroll() {
    scrollOffset.value = scrollController.offset;
  }

  Future<void> _initialLoad() async {
    isLoading.value = true;
    try {
      await Future.wait([refreshDeals(), _loadFlashDeals()]);
    } catch (e) {
      LogService.error('initial load failed', e);
    }
    isLoading.value = false;
  }

  Future<void> _loadFlashDeals() async {
    flashDeals.assignAll(await dealRepo.fetchFlashDeals());
  }

  Future<void> refreshDeals() async {
    _fetchVersion++; // 1. ดันเวอร์ชันขึ้นทันที Request เก่าที่ค้างอยู่ทั้งหมดจะถูกตัดทิ้ง
    final currentVersion = _fetchVersion;

    _isFetchingMore = true; // ล็อคไม่ให้ loadMore โผล่มาแทรกระหว่างรีเฟรช

    try {
      final res = await dealRepo.fetchDeals(page: 1);
      
      // ถ้าโดนรีเฟรชอันใหม่ซ้อนทับอีก ให้ข้ามการอัปเดต UI
      if (currentVersion != _fetchVersion) return;

      _page = 1;
      _totalPages = res.totalPages;
      deals.assignAll(res.items);
      refreshController.refreshCompleted();
      refreshController.resetNoData();
    } catch (e) {
      if (currentVersion == _fetchVersion) {
        refreshController.refreshFailed();
      }
    } finally {
      if (currentVersion == _fetchVersion) {
        _isFetchingMore = false;
      }
    }
  }

  Future<void> loadMore() async {
    // 1. เช็กและล็อคสถานะ "ทันที" ตั้งแต่บรรทัดแรกสุด
    if (_isFetchingMore || !hasMore) {
      if (!hasMore) refreshController.loadNoData();
      return;
    }

    _isFetchingMore = true;
    final currentVersion = _fetchVersion; // 2. จำเวอร์ชัน ณ วินาทีแรกที่เรียก loadMore
    final nextPage = _page + 1;

    try {
      // หากต้องการใส่ delay หน่วงเวลาทดสอบ ให้ใส่ไว้ "หลัง" จากจำ currentVersion แล้วเท่านั้น
      // await Future.delayed(const Duration(seconds: 3));

      final res = await dealRepo.fetchDeals(page: nextPage);

      // 3. ถ้าระหว่างรอ API มีการกด refreshเกิดขึ้น (_fetchVersion เปลี่ยน) ให้โยนข้อมูลนี้ทิ้งทันที
      if (currentVersion != _fetchVersion) {
        LogService.log('loadMore cancelled because refresh occurred');
        return;
      }

      _page = nextPage;
      _totalPages = res.totalPages;
      deals.addAll(res.items);
      refreshController.loadComplete();
    } catch (e) {
      LogService.error('loadMore failed', e);
      if (currentVersion == _fetchVersion) {
        refreshController.loadFailed();
      }
    } finally {
      if (currentVersion == _fetchVersion) {
        _isFetchingMore = false;
      }
    }
  }

  void scrollToTop() {
    scrollController.animateTo(0,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  void onClose() {
    scrollController.dispose();
    refreshController.dispose();
    super.onClose();
  }
}