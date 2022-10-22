import 'package:flutter/material.dart';

class Route1 extends StatelessWidget {
  static const String routeName = "Route1";

  const Route1({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(routeName),
      ),
      body: const Center(
        child: Text(
          routeName,
          style: TextStyle(
            fontSize: 32,
          ),
        ),
      ),
    );
  }
}
