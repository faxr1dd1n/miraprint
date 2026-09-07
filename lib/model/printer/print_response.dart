class PrintResponse {
  const PrintResponse({required this.success, required this.message});

  final bool success;
  final String message;

  Map<String, dynamic> toJson() {
    return {'success': success, 'message': message};
  }
}
