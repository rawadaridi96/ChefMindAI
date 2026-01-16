import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'currency_controller.g.dart';

@riverpod
class CurrencyController extends _$CurrencyController {
  @override
  bool build() {
    // Default to USD (true)
    return true;
  }

  void toggleCurrency() {
    state = !state;
  }

  String formatPrice(double usdAmount) {
    if (state) {
      return '\$${usdAmount.toStringAsFixed(2)}';
    } else {
      // Simulation: 1 USD = 1500 NGN (Nigerian Naira)
      // In a real app, this would fetch live rates.
      final ngnAmount = usdAmount * 1500;
      return '₦${_formatNumber(ngnAmount.round())}';
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}
