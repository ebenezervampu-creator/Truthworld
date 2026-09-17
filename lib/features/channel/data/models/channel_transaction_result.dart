class TransactionResult {
  TransactionResult({
    this.success = false,
    this.errorMessage,
    this.alreadySubscribed = false,
  });
  final bool success;
  final String? errorMessage;
  final bool alreadySubscribed;
}
