import 'package:flutter/material.dart';

class GuideStep {
  final String title;
  final String description;
  final IconData? icon;

  GuideStep({
    required this.title, 
    required this.description,
    this.icon
  });
}

class GuideItem {
  final String title;
  final String content; // Deprecated, keep for backward compatibility or overview
  final List<GuideStep> steps;
  final IconData icon;

  GuideItem({
    required this.title,
    required this.content,
    required this.icon,
    this.steps = const [],
  });
}

class AssemblyPoint {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;

  AssemblyPoint({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
  });
}
