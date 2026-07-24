import 'dart:async';
import 'dart:io';

class HardwareProfiler {
  bool _isTracking = false;
  
  double _peakCpu = 0.0;
  double _peakRamMb = 0.0;
  
  Timer? _timer;

  Future<void> init() async {
    // Initialize if needed
  }

  void startTracking() {
    _isTracking = true;
    _peakCpu = 0.0;
    _peakRamMb = ProcessInfo.currentRss / (1024 * 1024);
    
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!_isTracking) {
        timer.cancel();
        return;
      }
      
      final currentRam = ProcessInfo.currentRss / (1024 * 1024);
      if (currentRam > _peakRamMb) {
        _peakRamMb = currentRam;
      }
    });
  }

  Map<String, double> stopTracking() {
    _isTracking = false;
    _timer?.cancel();
    return {
      'peakCpu': _peakCpu,
      'peakRamMb': double.parse(_peakRamMb.toStringAsFixed(1)),
    };
  }
}

class HardwareSpecs {
  static int getDeviceRamMB() {
    if (Platform.isAndroid || Platform.isLinux) {
      try {
        final meminfo = File('/proc/meminfo').readAsStringSync();
        final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(meminfo);
        if (match != null) {
          return int.parse(match.group(1)!) ~/ 1024;
        }
      } catch (_) {}
    }
    return 4096; // Fallback to 4GB if unknown
  }
}
