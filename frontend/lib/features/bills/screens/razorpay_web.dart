import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void openRazorpayWeb({
  required Map<String, dynamic> options,
  required void Function(String paymentId, String orderId, String signature) onSuccess,
  required void Function(String message) onError,
}) {
  final jsOptions = _mapToJSObject(options);

  final successCb = ((JSString paymentId, JSString orderId, JSString signature) {
    onSuccess(paymentId.toDart, orderId.toDart, signature.toDart);
  }).toJS;

  final errorCb = ((JSString message) {
    onError(message.toDart);
  }).toJS;

  // Call window.openRazorpayCheckout directly
  globalContext.callMethod(
    'openRazorpayCheckout'.toJS,
    jsOptions,
    successCb,
    errorCb,
  );
}

JSObject _mapToJSObject(Map<String, dynamic> map) {
  final obj = JSObject();
  map.forEach((key, value) {
    if (value is String) {
      obj.setProperty(key.toJS, value.toJS);
    } else if (value is int) {
      obj.setProperty(key.toJS, value.toJS);
    } else if (value is double) {
      obj.setProperty(key.toJS, value.toJS);
    } else if (value is bool) {
      obj.setProperty(key.toJS, value.toJS);
    } else if (value is Map<String, dynamic>) {
      obj.setProperty(key.toJS, _mapToJSObject(value));
    }
  });
  return obj;
}
