

class Destination {

  String _street;
  String _number;
  String _city;
  String _neighborhood;
  String _postcode;
  double _latitude;
  double _longitude;

  Destination();

  double get longitude => _longitude;

  set longitude(double value) {  _longitude = value;  }

  double get latitude => _latitude;

  set latitude(double value) {  _latitude = value;  }

  String get postcode => _postcode;

  set postcode(String value) {  _postcode = value;  }

  String get neighborhood => _neighborhood;

  set neighborhood(String value) {  _neighborhood = value;  }

  String get city => _city;

  set city(String value) {  _city = value;  }

  String get number => _number;

  set number(String value) {  _number = value;  }

  String get street => _street;

  set street(String value) {  _street = value;  }
}