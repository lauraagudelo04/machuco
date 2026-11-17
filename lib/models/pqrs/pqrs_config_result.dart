/// Where a configuration value came from, in the order the chain tries them:
/// Supabase, then the local cache, then the safe defaults.
enum PqrsConfigSource { remote, cache, defaults }

/// A configuration value together with its [source].
///
/// When [source] is not [PqrsConfigSource.remote], [message] explains in
/// Spanish why the fresh value could not be read, so the UI can show it and
/// offer a retry.
class PqrsConfigResult<T> {
  const PqrsConfigResult({
    required this.value,
    required this.source,
    this.message,
  });

  final T value;
  final PqrsConfigSource source;
  final String? message;

  bool get isFresh => source == PqrsConfigSource.remote;
}
