import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequest.dart';
import 'package:uber/util/UserFirebase.dart';

class Race extends StatefulWidget {

  String idRequest;
  Race(this.idRequest);

  @override
  _RaceState createState() => _RaceState();
}

class _RaceState extends State<Race> {

  Completer<GoogleMapController> _controller = Completer();
  CameraPosition _cameraPosition = CameraPosition(target: LatLng(-23.563999, -46.653256));
  Set<Marker> _markers = {};
  Map<String, dynamic> _requestData;
  String _idRequest;
  Position _localDriver;
  String _statusRequest = StatusRequest.WAITING;

  //Controladores para exibição na tela
  String _buttonText = "Accept race";
  Color _buttonColor = Color(0xff1ebbd8);
  Function _buttonFunction;
  String _statusMessage = "";

  _changeMainButton(String text, Color color, Function function) {
    setState(() {
      _buttonText = text;
      _buttonColor = color;
      _buttonFunction = function;
    });
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _addListenerLocalization() {
    var geolocator = Geolocator();
    var locationOptions = LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 10);
    geolocator.getPositionStream(locationOptions).listen((Position position) {

      if ( position != null) {
        if(_idRequest != null && _idRequest.isNotEmpty) {
          if (_statusRequest != StatusRequest.WAITING) {

            //Actualizar local do passageiro
            UserFirebase.updateLocalizationData(
                _idRequest, position.latitude, position.longitude
            );

          } else {
            setState(() {  _localDriver = position;  });
            _statusWaiting();
          }
        }
      }
    });
  }

  _recoverLastKnowPosition() async {
    Position position = await Geolocator()
        .getLastKnownPosition(desiredAccuracy: LocationAccuracy.high);

    if (position != null) {
      //Atualizar localização em tempo real do motorista
    }
  }

  _moveCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _showMarker(Position local, String icon, String infoWindow) async {

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio), icon)
        .then((BitmapDescriptor bitmapDescriptor) {
          Marker marker = Marker(
              markerId: MarkerId(icon),
              position: LatLng(local.latitude, local.longitude),
              infoWindow: InfoWindow( title: infoWindow),
              icon: bitmapDescriptor
          );

          setState(() {  _markers.add(marker);  });
        });
  }

  _recoverRequest() async {
    String idRequest = widget.idRequest;
    Firestore db = Firestore.instance;
    DocumentSnapshot documentSnapshot = await db
        .collection("requests").document(idRequest).get();
  }

  _addRequestListener() async {
    Firestore db = Firestore.instance;

    await db.collection("requests")
        .document(_idRequest)
        .snapshots()
        .listen((snapshot) {

          if (snapshot.data != null) {
            _requestData = snapshot.data;
            Map<String, dynamic> data = snapshot.data;
            _statusRequest = data["status"];

            switch(_statusRequest) {
              case StatusRequest.WAITING :
                _statusWaiting();
                break;
              case StatusRequest.ON_WAY :
                _statusOnWay();
                break;
              case StatusRequest.TRAVEL :
                _statusTravel();
                break;
              case StatusRequest.DONE :
                _statusDone();
                break;
              case StatusRequest.CONFIRMED :
                _statusConfirmed();
                break;
            }
          }
    });
  }

  _statusWaiting(){
    _changeMainButton("Accept Race", Color(0xff1ebbd8), () {  _acceptRace();  });

    if( _localDriver != null) {
      double driverLat = _localDriver.latitude;
      double driverLon = _localDriver.longitude;

      Position position = Position(latitude: driverLat, longitude: driverLon);

      _showMarker(position, "images/motorista.png", "Driver");

      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19
      );

      _moveCamera(cameraPosition);
    }
  }

  _statusOnWay(){
    _statusMessage = "On the way to Passenger";
    _changeMainButton("Start race", Color(0xff1ebbd8), () {  _startRace();  });

    double passengerLatitude = _requestData["passenger"]["latitude"];
    double passengerLongitude = _requestData["passenger"]["longitude"];

    double driverLatitude = _requestData["driver"]["latitude"];
    double driverLongitude = _requestData["driver"]["longitude"];

    _showTwoMarkers(
        LatLng(driverLatitude,driverLongitude),
        LatLng(passengerLatitude,passengerLongitude)
    );

    //Southwest.latitude <= northeast.latitude é uma regra
    var nLat, nLon, sLat, sLon;
    if(driverLatitude <= passengerLatitude) {
      sLat = driverLatitude;
      nLat = passengerLatitude;
    } else {
      sLat = passengerLatitude;
      nLat = driverLatitude;
    }

    if(driverLongitude <= passengerLongitude) {
      sLon = driverLongitude;
      nLon = passengerLongitude;
    } else {
      sLon = passengerLongitude;
      nLon = driverLongitude;
    }

    _moveCameraBounds(
        LatLngBounds(
          northeast: LatLng(nLat, nLon),
          southwest: LatLng(sLat, sLon)
        )
    );
  }

  _finishRace() {
    Firestore db = Firestore.instance;
    db.collection("requests").document(_idRequest).updateData({
      "status" : StatusRequest.DONE
    });

    String idPassenger = _requestData["passenger"]["idUser"];
    db.collection("active_requests").document(idPassenger).updateData({
      "status" : StatusRequest.DONE});

    String idDriver = _requestData["driver"]["idUser"];
    db.collection("active_driver_request").document(idDriver).updateData({
      "status" : StatusRequest.DONE});
  }

  _statusDone() async {
    //Calcula valor da corrida
    double destinationLatitude = _requestData["destination"]["latitude"];
    double destinationLongitude = _requestData["destination"]["longitude"];

    double originLatitude = _requestData["origin"]["latitude"];
    double originLongitude = _requestData["origin"]["longitude"];

    double distanceInMeters = await Geolocator().distanceBetween(
        originLatitude, originLongitude, destinationLatitude, destinationLongitude);

    //Converte para KM
    double distanceKm = distanceInMeters / 1000;
    //1.50 é o valor cobrado por KM
    double tripValue = distanceKm * 1.50;
    //Formatar valor viagem
    var f = new NumberFormat("#,##0.00", "pt_PT");
    var tripValueFormatted = f.format(tripValue);

    _statusMessage = "Trip completed";
    _changeMainButton("Confirm - \€ ${tripValueFormatted}", Color(0xff1ebbd8), () {  _confirmRace();  });

    _markers = {};
    Position position = Position(latitude: destinationLatitude, longitude: destinationLongitude);

    _showMarker(position, "images/destino.png", "Destiny");

    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19
    );

    _moveCamera(cameraPosition);
  }

  _statusConfirmed() {
    Navigator.pushReplacementNamed(context, "/driver-screen");
  }

  _confirmRace() {
    Firestore db = Firestore.instance;
    db.collection("requests").document(_idRequest).updateData({
      "status" : StatusRequest.CONFIRMED
    });

    String idPassenger = _requestData["passenger"]["idUser"];
    db.collection("active_requests").document(idPassenger).delete();

    String idDriver = _requestData["driver"]["idUser"];
    db.collection("active_driver_request").document(idDriver).delete();
  }

  _statusTravel(){
    _statusMessage = "Traveling";
    _changeMainButton("Finish race", Color(0xff1ebbd8), () {  _finishRace();  });

    double destinationLatitude = _requestData["destination"]["latitude"];
    double destinationLongitude = _requestData["destination"]["longitude"];

    double originLatitude = _requestData["driver"]["latitude"];
    double originLongitude = _requestData["driver"]["longitude"];

    _showTwoMarkers(
        LatLng(originLatitude,originLongitude),
        LatLng(destinationLatitude,destinationLongitude)
    );

    //Southwest.latitude <= northeast.latitude é uma regra
    var nLat, nLon, sLat, sLon;
    if(originLatitude <= destinationLatitude) {
      sLat = originLatitude;
      nLat = destinationLatitude;
    } else {
      sLat = destinationLatitude;
      nLat = originLatitude;
    }

    if(originLongitude <= destinationLongitude) {
      sLon = originLongitude;
      nLon = destinationLongitude;
    } else {
      sLon = destinationLongitude;
      nLon = originLongitude;
    }

    _moveCameraBounds(
        LatLngBounds(
            northeast: LatLng(nLat, nLon),
            southwest: LatLng(sLat, sLon)
        )
    );
  }

  _startRace() {
    Firestore db = Firestore.instance;
    db.collection("requests").document(_idRequest).updateData({
      "origin" : {
        "latitude" : _requestData["driver"]["latitude"],
        "longitude" : _requestData["driver"]["longitude"],
      },
      "status" : StatusRequest.TRAVEL
    });

    String idPassenger = _requestData["passenger"]["idUser"];
    db.collection("active_requests").document(idPassenger).updateData({
      "status" : StatusRequest.TRAVEL});

    String idDriver = _requestData["driver"]["idUser"];
    db.collection("active_driver_request").document(idDriver).updateData({
      "status" : StatusRequest.TRAVEL});
  }

  _moveCameraBounds(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newLatLngBounds(latLngBounds, 100));
  }

  _showTwoMarkers(LatLng latLngDriver, LatLng latLngPassenger) {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    Set<Marker> _markerList = {};
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "images/motorista.png"
    ).then((BitmapDescriptor icon) {
      Marker driverMarker = Marker(
          markerId: MarkerId("driver-marker"),
          position: LatLng(latLngDriver.latitude, latLngDriver.longitude),
          infoWindow: InfoWindow( title: "Driver location"),
          icon: icon
      );
      _markerList.add(driverMarker);
    });

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "images/passageiro.png"
    ).then((BitmapDescriptor icon) {
      Marker passengerMarker = Marker(
          markerId: MarkerId("passenger-marker"),
          position: LatLng(latLngPassenger.latitude, latLngPassenger.longitude),
          infoWindow: InfoWindow( title: "Passenger location"),
          icon: icon
      );
      _markerList.add(passengerMarker);
    });

    setState(() {  _markers = _markerList;  });
  }

  _acceptRace() async {
    Firestore db = Firestore.instance;
    String idRequest = _requestData["id"];

    Usuario driver = await UserFirebase.getDataLoggedUser();
    driver.latitude = _localDriver.latitude;
    driver.longitude = _localDriver.longitude;

    db.collection("requests").document(idRequest).updateData({
      "driver" : driver.toMap(),
      "status" : StatusRequest.ON_WAY,
    }).then((_) {
      //Atualizar requisição activa
      String idPassenger = _requestData["passenger"]["idUser"];
      db.collection("active_requests").document(idPassenger).updateData({
        "status" : StatusRequest.ON_WAY,
      });
      //Salvar requisição activa para motorista
      String idDriver = driver.idUser;
      db.collection("active_driver_request").document(idDriver).setData({
        "id_request" : idRequest,
        "id_user" : idDriver,
        "status" : StatusRequest.ON_WAY,
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _idRequest = widget.idRequest;
    //adicionar listener para mudanças na requisição
    _addRequestListener();

    //_recoverLastKnowPosition();
    _addListenerLocalization();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text("Race - " + _statusMessage)
        ),
        body: Container(
            child: Stack(
                children: [
                  GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: _cameraPosition,
                    onMapCreated: _onMapCreated,
                    //myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    markers: _markers,
                  ),
                  Positioned(
                      right: 0,
                      left: 0,
                      bottom: 0,
                      child: Padding(
                          padding: Platform.isIOS
                              ? EdgeInsets.fromLTRB(20, 10, 20, 25)
                              : EdgeInsets.all(10),
                          child: RaisedButton(
                              child: Text(_buttonText,
                                  style: TextStyle(color: Colors.white, fontSize: 20)),
                              color: _buttonColor,
                              padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                              onPressed: _buttonFunction
                          )
                      )
                  )
                ]
            )
        ));
  }
}
