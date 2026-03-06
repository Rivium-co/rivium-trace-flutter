enum MessageLevel {
  debug('debug'),
  info('info'),
  warning('warning'),
  error('error');

  final String value;
  const MessageLevel(this.value);
}
