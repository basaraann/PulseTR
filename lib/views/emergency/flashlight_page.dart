import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:torch_light/torch_light.dart';

class FlashlightPage extends StatefulWidget {
  const FlashlightPage({super.key});

  @override
  State<FlashlightPage> createState() => _FlashlightPageState();
}

class _FlashlightPageState extends State<FlashlightPage> {
  // Modes: 0 = Off, 1 = On (Steady), 2 = SOS (Strobe)
  int _mode = 0; 
  Timer? _strobeTimer;
  bool _isScreenWhite = false;
  bool _isTorchAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkTorchAvailability();
  }

  Future<void> _checkTorchAvailability() async {
    try {
      _isTorchAvailable = await TorchLight.isTorchAvailable();
    } catch (e) {
      debugPrint("Torch check error: $e");
    }
  }

  void _toggleMode() {
    setState(() {
      _mode = (_mode + 1) % 3;
    });
    _handleModeChange();
  }

  void _handleModeChange() async {
    _strobeTimer?.cancel();
    
    try {
      if (_mode == 0) {
        // Off
        _isScreenWhite = false;
        if (_isTorchAvailable) await TorchLight.disableTorch();
      } else if (_mode == 1) {
        // Steady
        _isScreenWhite = true;
        if (_isTorchAvailable) await TorchLight.enableTorch();
      } else if (_mode == 2) {
        // SOS Strobe
        _startSosStrobe();
      }
    } catch (e) {
      debugPrint("Torch error: $e");
    }
    setState(() {});
  }

  void _startSosStrobe() {
    int tick = 0;
    const duration = Duration(milliseconds: 200); // Fast ticks
    
    _strobeTimer = Timer.periodic(duration, (timer) async {
      tick++;
      bool light = false;
      int phase = tick % 24; 

      if (phase < 6) { 
        light = (phase % 2 == 0);
      } else if (phase < 18) {
        int p = (phase - 6) % 4;
        light = (p < 2);
      } else {
        light = (phase % 2 == 0);
      }

      if (_isScreenWhite != light) {
        setState(() => _isScreenWhite = light);
        try {
          if (_isTorchAvailable) {
            if (light) {
              await TorchLight.enableTorch();
            } else {
              await TorchLight.disableTorch();
            }
          }
        } catch (e) {
             debugPrint("Torch strobe error: $e");
        }
      }
    });
  }

  @override
  void dispose() {
    _strobeTimer?.cancel();
    _disableTorchSafe();
    super.dispose();
  }

  Future<void> _disableTorchSafe() async {
    try {
      if (_isTorchAvailable) await TorchLight.disableTorch();
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isScreenWhite ? Colors.white : Colors.black,
      appBar: _mode == 0 ? AppBar(
        title: const Text('Ekran Feneri'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ) : null, 
      body: InkWell(
        onTap: _toggleMode,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(
                     padding: const EdgeInsets.all(30),
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       border: Border.all(
                         color: _mode == 0 ? Colors.grey : (_mode == 1 ? Colors.black : Colors.red),
                         width: 4
                       ),
                       color: _isScreenWhite ? Colors.white : Colors.grey[900],
                       boxShadow: _mode != 0 ? [
                         BoxShadow(
                           color: _mode == 1 ? Colors.white.withOpacity(0.8) : Colors.red.withOpacity(0.8),
                           blurRadius: 50,
                           spreadRadius: 20
                         )
                       ] : []
                     ),
                     child: Icon(
                       Icons.flashlight_on,
                       size: 60,
                       color: _mode == 0 ? Colors.grey : (_mode == 1 ? Colors.black : Colors.red),
                     ),
                   ),
                   const SizedBox(height: 40),
                   Text(
                     _mode == 0 ? 'KAPALI' : (_mode == 1 ? 'AÇIK' : 'SOS MODU'),
                     style: TextStyle(
                       fontSize: 32,
                       fontWeight: FontWeight.bold,
                       color: _isScreenWhite ? Colors.black : Colors.white,
                     ),
                   ),
                   const SizedBox(height: 10),
                   Text(
                     'Dokun ve Değiştir',
                     style: TextStyle(
                       color: _isScreenWhite ? Colors.grey[600] : Colors.grey[400],
                     ),
                   )
                ],
              ),
            ),
             if (_mode != 0)
              Positioned(
                top: 40,
                left: 20,
                child: SafeArea(
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: _isScreenWhite ? Colors.black : Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
