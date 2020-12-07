import 'package:flutter/material.dart';

class Usuario {

  String _idUser;
  String _name;
  String _email;
  String _pass;
  String _userType;

  double _latitude;
  double _longitude;

  Usuario();

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      "idUser" : this.idUser,
      "name" : this.name,
      "email" : this.email,
      "userType" : this.userType,
      "latitude" : this.latitude,
      "longitude" : this.longitude,
    };
    return map;
  }

  String verifyUserType (bool userType) {
    return userType ? "driver" : "passenger";
  }



  String get userType => _userType;

  set userType(String value) {  _userType = value;  }

  String get pass => _pass;

  set pass(String value) {  _pass = value;  }

  String get email => _email;

  set email(String value) {  _email = value;  }

  String get name => _name;

  set name(String value) {  _name = value;  }

  String get idUser => _idUser;

  set idUser(String value) {  _idUser = value;  }

  double get latitude => _latitude;

  set latitude(double value) {  _latitude = value;  }

  double get longitude => _longitude;

  set longitude(double value) {  _longitude = value;  }
}