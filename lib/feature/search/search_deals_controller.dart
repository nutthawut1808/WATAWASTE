import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class SearchDealsController extends GetxController {
  final DealRepo dealRepo;

  SearchDealsController({required this.dealRepo});

  final results = <DealModel>[].obs;
  final isLoading = false.obs;
  final hasSearched = false.obs;

  // เพิ่มตัวแปรเก็บ query ล่าสุดสำหรับป้องกัน Race Condition
  String _currentQuery = '';

  void onQueryChanged(String query) {
    _currentQuery = query; // อัปเดต query ล่าสุดทันทีที่พิมพ์
    _search(query);
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      results.clear();
      hasSearched.value = false;
      isLoading.value = false;
      return;
    }
    
    isLoading.value = true;
    hasSearched.value = true;
    
    try {
      final found = await dealRepo.search(query);
      
      // ตรวจสอบว่า query ที่ได้ผลลัพธ์มานี้ ยังตรงกับ query ล่าสุดที่ผู้ใช้พิมพ์อยู่หรือไม่
      if (_currentQuery == query) {
        results.assignAll(found);
      }
    } catch (e) {
      LogService.error('search failed', e);
    } finally {
      // ปิด loading เฉพาะเมื่อเป็น query ล่าสุดเท่านั้น
      if (_currentQuery == query) {
        isLoading.value = false;
      }
    }
  }
}