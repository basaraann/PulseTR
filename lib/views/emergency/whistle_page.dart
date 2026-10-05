import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class WhistlePage extends StatefulWidget {
  const WhistlePage({super.key});

  @override
  State<WhistlePage> createState() => _WhistlePageState();
}

class _WhistlePageState extends State<WhistlePage> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Prepare player
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
    _animController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _toggleWhistle() {
    if (_isPlaying) {
      _stopWhistle();
    } else {
      _startWhistle();
    }
  }

  void _startWhistle() async {
    setState(() => _isPlaying = true);
    _animController.repeat(reverse: true);
    
    try {
      // Play custom asset
      // Ensure volume is max
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setSource(AssetSource('sounds/whistle.wav'));
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint("Audio error: $e");
    }
  }

  void _stopWhistle() async {
    setState(() => _isPlaying = false);
    _animController.stop();
    _animController.reset();
    try {
      await _audioPlayer.stop();
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background for emergency
      appBar: AppBar(
        title: const Text('Acil Durum Düdüğü'),
        backgroundColor: Colors.transparent, 
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             GestureDetector(
               onTap: _toggleWhistle,
               child: AnimatedBuilder(
                 animation: _animController,
                 builder: (context, child) {
                   return Container(
                     padding: EdgeInsets.all(30 + (_animController.value * 20)),
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       color: _isPlaying ? Colors.red : Colors.grey[800],
                       boxShadow: [
                         if (_isPlaying)
                           BoxShadow(
                             color: Colors.red.withOpacity(0.5),
                             blurRadius: 50,
                             spreadRadius: 20
                           )
                       ]
                     ),
                     child: const Icon(
                       Icons.campaign, // Whistle icon alternative
                       size: 80,
                       color: Colors.white,
                     ),
                   );
                 },
               ),
             ),
             const SizedBox(height: 50),
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 40),
               child: Text(
                 _isPlaying ? 'DÜDÜK ÇALIYOR!' : 'DÜDÜK ÇALMAK İÇİN DOKUN',
                 textAlign: TextAlign.center,
                 style: const TextStyle(
                   fontSize: 24, 
                   fontWeight: FontWeight.bold,
                   color: Colors.white
                 ),
               ),
             ),
             const SizedBox(height: 20),
             const Padding(
               padding: EdgeInsets.symmetric(horizontal: 40),
               child: Text(
                 'Sesinizi duyurmak için butona basın. Ekran açık kaldığı sürece çalacaktır.',
                 textAlign: TextAlign.center,
                 style: TextStyle(color: Colors.grey),
               ),
             )
          ],
        ),
      ),
    );
  }
}
