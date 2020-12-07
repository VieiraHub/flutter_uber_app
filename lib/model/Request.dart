import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uber/model/Destination.dart';
import 'package:uber/model/Usuario.dart';

class Request {

  String _id;
  String _status;
  Usuario _passenger;
  Usuario _driver;
  Destination _destination;

  Request(){
    Firestore db = Firestore.instance;
    DocumentReference ref = db.collection("requests").document();
    this.id = ref.documentID;
  }


  Map<String, dynamic> toMap() {

    Map<String, dynamic> passengerData = {
      "name" : this.passenger.name,
      "email" : this.passenger.email,
      "userType" : this.passenger.userType,
      "idUser" : this.passenger.idUser,
      "latitude" : this.passenger.latitude,
      "longitude" : this.passenger.longitude
    };

    Map<String, dynamic> destinationData = {
      "street" : this.destination.street,
      "number" : this.destination.number,
      //"city" : this.destination.city,  ELE NAO TEM!!!
      "neighborhood" : this.destination.neighborhood,
      "postcode" : this.destination.postcode,
      "latitude" : this.destination.latitude,
      "longitude" : this.destination.longitude,
    };

    Map<String, dynamic> requestData = {
      "id" : this.id,
      "status" : this.status,
      "passenger" : passengerData,
      "driver" : null,
      "destination" : destinationData,
    };
    return requestData;
  }

  Destination get destination => _destination;

  set destination(Destination value) {  _destination = value;  }

  Usuario get driver => _driver;

  set driver(Usuario value) {  _driver = value;  }

  Usuario get passenger => _passenger;

  set passenger(Usuario value) {  _passenger = value;  }

  String get status => _status;

  set status(String value) {  _status = value;  }

  String get id => _id;

  set id(String value) {  _id = value;  }
}