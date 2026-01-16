import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'payment_service.g.dart';

@riverpod
PaymentService paymentService(PaymentServiceRef ref) {
  return PaymentService();
}

class PaymentService {
  // TODO: [ACTION REQUIRED] Replace this with your actual Lemon Squeezy Store URL
  // Example: https://my-saas-app.lemonsqueezy.com
  static const String _storeDomain = 'https://chefmind-test.lemonsqueezy.com';

  String getCheckoutUrl(String variantId, {String? userEmail}) {
    // Construct the checkout URL.
    var url = '$_storeDomain/checkout/buy/$variantId';

    // Add Success Redirect (Deep Link)
    url += '?checkout[success_url]=chefmind://payment-success';

    if (userEmail != null) {
      url += '&checkout[email]=$userEmail';
    }
    return url;
  }

  String getBillingPortalUrl() {
    // In Lemon Squeezy, the customer portal link is usually:
    // https://[store].lemonsqueezy.com/billing
    return '$_storeDomain/billing';
  }
}
