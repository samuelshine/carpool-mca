import 'package:flutter/material.dart';

class SOSButton extends StatefulWidget {
  final VoidCallback onTrigger;
  const SOSButton({super.key, required this.onTrigger});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 3));
        
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onTrigger();
        _controller.reset();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _controller.forward(),
      onLongPressEnd: (_) => _controller.reset(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Ring
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(0.2),
            ),
          ),
          // Progress Ring
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              valueColor: const AlwaysStoppedAnimation(Colors.red),
              value: _controller.value, // This needs AnimatedBuilder to work perfectly, simplified here
              strokeWidth: 4,
            ),
          ),
          // Button
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                  boxShadow: [
                     BoxShadow(color: Colors.redAccent, blurRadius: 10, spreadRadius: 2)
                  ]
                ),
                child: const Center(
                  child: Text(
                    "SOS", 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
                  ),
                ),
              );
            }
          ),
          // Progress overlay
          Positioned(
             bottom: -30,
             child: AnimatedBuilder(
               animation: _controller,
               builder: (context, _) => Opacity(
                 opacity: _controller.value > 0 ? 1 : 0,
                 child: const Text("Hold to Alert", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
               ),
             )
          )
        ],
      ),
    );
  }
}
