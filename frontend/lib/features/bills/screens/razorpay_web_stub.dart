// Stub for non-web platforms — openRazorpayWeb is never called on native.
void openRazorpayWeb({
  required Map<String, dynamic> options,
  required void Function(String paymentId, String orderId, String signature) onSuccess,
  required void Function(String message) onError,
}) {
  throw UnsupportedError('Razorpay web checkout is only supported on Flutter Web.');
}
