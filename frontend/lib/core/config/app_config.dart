class AppConfig {
  /// URL base de la API.
  ///
  /// El valor por defecto sirve para depuracion local: en un telefono fisico
  /// conectado por USB hay que publicar el puerto con
  /// `adb reverse tcp:3000 tcp:3000`. Para otro entorno compile con
  /// `--dart-define=API_BASE_URL=http://<ip-local>:3000`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  /// Datos de soporte que se muestran en la pantalla de inicio de sesion.
  static const String supportPhone = '71338567';
  static const String supportWhatsapp = '+59171338567';
  static const String supportWhatsappNumber = '59171338567';

  static const String supportWhatsappMessage =
      'Hola, necesito ayuda con BoviSense AI.';

  /// Conversacion de WhatsApp con soporte, con el mensaje ya codificado.
  static Uri get supportWhatsappUri => Uri(
    scheme: 'whatsapp',
    host: 'send',
    queryParameters: {
      'phone': supportWhatsappNumber,
      'text': supportWhatsappMessage,
    },
  );
}
