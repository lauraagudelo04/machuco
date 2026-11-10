import 'dart:async';

/// Reintenta una sincronización que falló por falta de conexión.
///
/// El plan es de retroceso exponencial: 2 s, 5 s, 10 s, 30 s y luego 60 s
/// hasta agotar [defaultDelays] (8 intentos). El módulo de propietarios lo
/// usa para volver a subir los cambios y los borrados pendientes cuando la
/// red regresa, sin depender de que el usuario pulse «Reintentar».
///
/// No conoce Firestore ni la base local: sólo invoca el callback [attempt] y
/// avisa con [onStateChanged] para que la vista se reconstruya.
class OwnerSyncRetryScheduler {
  OwnerSyncRetryScheduler({
    required Future<void> Function() attempt,
    List<Duration>? delays,
    this.onStateChanged,
  }) : delays = List.unmodifiable(delays ?? defaultDelays) {
    _attempt = attempt;
  }

  late final Future<void> Function() _attempt;

  /// Ocho intentos: 2 s, 5 s, 10 s, 30 s y 60 s desde el quinto en adelante.
  static const defaultDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 60),
    Duration(seconds: 60),
    Duration(seconds: 60),
  ];

  /// Espera antes de cada intento, en orden.
  final List<Duration> delays;

  /// Se llama cada vez que cambia el estado (programado, ejecutando, agotado).
  final void Function()? onStateChanged;

  Timer? _timer;
  int _attemptNumber = 0;
  bool _running = false;
  bool _disposed = false;

  /// Número del próximo intento (1..8) o del último ejecutado.
  int get attempt => _attemptNumber;

  /// Total de intentos disponibles antes de rendirse.
  int get maxAttempts => delays.length;

  /// `true` mientras hay un reintento programado.
  bool get isScheduled => _timer?.isActive ?? false;

  /// `true` cuando ya se agotaron los intentos automáticos.
  bool get isExhausted => _attemptNumber >= delays.length && !isScheduled;

  /// Programa el siguiente reintento tras un fallo de red.
  ///
  /// Si ya se agotaron los intentos no hace nada: el usuario conserva el
  /// botón manual «Reintentar».
  void notifyNetworkFailure() {
    if (_disposed) return;
    if (_attemptNumber >= delays.length) {
      onStateChanged?.call();
      return;
    }
    _timer?.cancel();
    final delay = delays[_attemptNumber];
    _attemptNumber++;
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(_run());
    });
    onStateChanged?.call();
  }

  /// Cancela el reintento porque la sincronización salió bien.
  void notifySuccess() {
    _timer?.cancel();
    _timer = null;
    _attemptNumber = 0;
    onStateChanged?.call();
  }

  /// Reinicia el contador y detiene cualquier reintento programado.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _attemptNumber = 0;
    onStateChanged?.call();
  }

  /// Ejecuta el callback de inmediato, sin esperar al temporizador.
  Future<void> retryNow() async {
    _timer?.cancel();
    _timer = null;
    await _run();
  }

  /// Libera el temporizador; el controlador lo llama en `dispose`.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _run() async {
    if (_disposed || _running) return;
    _running = true;
    try {
      await _attempt();
    } finally {
      _running = false;
    }
  }
}
