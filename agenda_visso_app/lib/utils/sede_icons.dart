import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

const sedeIconKeys = [
  'store',
  'medical_services',
  'visibility',
  'local_hospital',
  'home',
  'business',
  'apartment',
  'building',
  'glasses',
  'scan_eye',
  'hospital',
  'map_pin',
  'phone',
  'clock',
  'star',
  'shopping_bag',
  'landmark',
  'school',
  'parking_circle',
  'dental',
  'heart_handshake',
  'pill',
  'thermometer',
  'wheelchair',
];

IconData iconoDeSede(String icono) {
  switch (icono) {
    case 'store': return LucideIcons.store;
    case 'medical_services': return LucideIcons.heartPulse;
    case 'visibility': return LucideIcons.eye;
    case 'local_hospital': return LucideIcons.stethoscope;
    case 'home': return LucideIcons.home;
    case 'business': return LucideIcons.building2;
    case 'apartment': return LucideIcons.building;
    case 'building': return LucideIcons.building2;
    case 'glasses': return LucideIcons.glasses;
    case 'scan_eye': return LucideIcons.scan;
    case 'hospital': return LucideIcons.stethoscope;
    case 'map_pin': return LucideIcons.mapPin;
    case 'phone': return LucideIcons.phone;
    case 'clock': return LucideIcons.clock;
    case 'star': return LucideIcons.star;
    case 'shopping_bag': return LucideIcons.shoppingBag;
    case 'landmark': return LucideIcons.landmark;
    case 'school': return LucideIcons.school;
    case 'parking_circle': return LucideIcons.parkingCircle;
    case 'dental': return LucideIcons.stethoscope;
    case 'heart_handshake': return LucideIcons.heartHandshake;
    case 'pill': return LucideIcons.pill;
    case 'thermometer': return LucideIcons.thermometer;
    case 'wheelchair': return LucideIcons.accessibility;
    default: return LucideIcons.store;
  }
}
