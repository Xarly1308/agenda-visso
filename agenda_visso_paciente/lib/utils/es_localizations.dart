import 'package:flutter/material.dart';

class EsMaterialLocalizations extends DefaultMaterialLocalizations {
  @override
  String get okButtonLabel => 'Aceptar';
  @override
  String get cancelButtonLabel => 'Cancelar';
}

class EsLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const EsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'es';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    return EsMaterialLocalizations();
  }

  @override
  bool shouldReload(EsLocalizationsDelegate old) => false;
}
