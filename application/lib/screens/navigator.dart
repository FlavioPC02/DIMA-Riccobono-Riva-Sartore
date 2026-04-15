import 'package:flutter/material.dart';

class NavigatorScreen extends StatefulWidget {
  //ottengo un Map<String, dynamic> id, name, coordinates
  final Map<String, dynamic> trail;
  
  const NavigatorScreen({
    required this.trail,
    super.key,
  });

  @override
  State<NavigatorScreen> createState(){
    return _NavigatorScreenState();
  } 
}

class _NavigatorScreenState extends State<NavigatorScreen> {
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber,
    );
  }
}