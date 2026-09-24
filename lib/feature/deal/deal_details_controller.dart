import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../service/analytics_service.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class DealDetailsController extends GetxController {
  final DealRepo dealRepo;
  final CartService cartService;
  final AnalyticsService analytics;

  DealDetailsController({
    required this.dealRepo,
    required this.cartService,
    required this.analytics,
  });

  // เปลี่ยนมาใช้ Rxn เพื่อรองรับการโหลดข้อมูลแบบ Asynchronous จาก Deep Link
  final deal = Rxn<DealModel>();
  final isLoading = true.obs;
  Worker? _cartWorker;

  final _quantityLeft = RxnInt();
  int? get quantityLeft => _quantityLeft.value;

  @override
  void onInit() {
    super.onInit();
    _loadInitialData();
    _cartWorker = ever(cartService.itemCount, (_) => _recheckAvailability());
  }

  Future<void> _loadInitialData() async {
    isLoading.value = true;
    try {
      if (Get.arguments is DealModel) {
        // กรณีเปิดจาก Home Feed (มี DealModel แนบมาด้วย)
        final argDeal = Get.arguments as DealModel;
        deal.value = argDeal;
        _quantityLeft.value = argDeal.quantityLeft;
        _logAnalytics(argDeal.id);
      } else {
        // กรณีเปิดจาก Deep Link (ไม่มี arguments ต้องดึง id จาก parameters มา fetch)
        final idStr = Get.parameters['id'];
        if (idStr != null) {
          final id = int.tryParse(idStr);
          if (id != null) {
            final fetchedDeal = await dealRepo.fetchById(id);
            deal.value = fetchedDeal;
            _quantityLeft.value = fetchedDeal.quantityLeft;
            _logAnalytics(fetchedDeal.id);
          }
        }
      }
    } catch (e) {
      LogService.error('failed to load deal details', e);
    } finally {
      isLoading.value = false;
    }
  }

  void _logAnalytics(int dealId) {
    analytics.logEvent('deal_details_view', {
      'deal_id': dealId,
      'source': Get.parameters['source'] ?? 'unknown',
    });
  }

  @override
  void onClose() {
    _cartWorker?.dispose();
    super.onClose();
  }

  Future<void> _recheckAvailability() async {
    final currentDeal = deal.value;
    if (currentDeal == null) return;

    LogService.log('re-checking availability for deal ${currentDeal.id}');
    try {
      final fresh = await dealRepo.fetchById(currentDeal.id);
      _quantityLeft.value = fresh.quantityLeft;
    } catch (e) {
      LogService.error('failed re-checking availability', e);
    }
  }

  void addToCart() {
    final currentDeal = deal.value;
    if (currentDeal == null) return;

    cartService.add(currentDeal);
    Get.snackbar(
      'Added to bag',
      '${currentDeal.name} — pick up ${currentDeal.pickupWindow.label}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }
}