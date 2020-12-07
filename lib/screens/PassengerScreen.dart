import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';

import 'package:uber/model/Destination.dart';
import 'package:uber/model/Marcador.dart';
import 'package:uber/model/Request.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequest.dart';
import 'package:uber/util/UserFirebase.dart';

class PassengerScreen extends StatefulWidget {
  @override
  _PassengerScreenState createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen> {
  TextEditingController _controllerDestination =
      TextEditingController(text: "av. Liberdade, 194");
  List<String> itensMenu = ["Settings", "Logout"];
  Completer<GoogleMapController> _controller = Completer();
  CameraPosition _cameraPosition =
      CameraPosition(target: LatLng(-23.563999, -46.653256));
  Set<Marker> _markers = {};
  String _idRequest;
  Position _localPassenger;
  Map<String, dynamic> _requestData;
  StreamSubscription<DocumentSnapshot> _streamSubscriptionRequests;

  //Controladores para exibição na tela
  bool _showDestinationAddressBox = true;
  String _buttonText = "Call Uber";
  Color _buttonColor = Color(0xff1ebbd8);
  Function _buttonFunction;

  _logoutUser() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    await auth.signOut();
    Navigator.pushReplacementNamed(context, "/");
  }

  _chooseMenuItem(String choose) {
    switch (choose) {
      case "Logout":
        _logoutUser();
        break;
      case "Settings":
        break;
    }
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _addListenerLocalization() {
    var geolocator = Geolocator();
    var locationOptions =
        LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 10);

    geolocator.getPositionStream(locationOptions).listen((Position position) {
      if (_idRequest != null && _idRequest.isNotEmpty) {
        //Actualizar local do passageiro
        UserFirebase.updateLocalizationData(
            _idRequest, position.latitude, position.longitude);
      } else {
        setState(() {
          _localPassenger = position;
        });
        _statusUberNotCalled();
      }
    });
  }

  _recoverLastKnowPosition() async {
    Position position = await Geolocator()
        .getLastKnownPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      if (position != null) {
        _showPassengerMarker(position);

        _cameraPosition = CameraPosition(
            target: LatLng(position.latitude, position.longitude), zoom: 19);
        _localPassenger = position;
        _moveCamera(_cameraPosition);
      }
    });
  }

  _moveCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _showPassengerMarker(Position local) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            "images/passageiro.png")
        .then((BitmapDescriptor icon) {
      Marker passengerMarker = Marker(
          markerId: MarkerId("passenger-marker"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: "My place"),
          icon: icon);
      setState(() {
        _markers.add(passengerMarker);
      });
    });
  }

  _callUber() async {
    String destinationAddress = _controllerDestination.text;
    if (destinationAddress.isNotEmpty) {
      List<Placemark> addressList =
          await Geolocator().placemarkFromAddress(destinationAddress);

      if (addressList != null && addressList.length > 0) {
        Placemark address = addressList[0];
        Destination destination = Destination();
        destination.city = address.administrativeArea;
        destination.postcode = address.postalCode;
        destination.neighborhood = address.subLocality;
        destination.street = address.thoroughfare;
        destination.number = address.subThoroughfare;

        destination.latitude = address.position.latitude;
        destination.longitude = address.position.longitude;

        String addressConfirmation;
        addressConfirmation = "\n City: " + destination.city;
        addressConfirmation +=
            "\n Street: " + destination.street + ", " + destination.number;
        addressConfirmation += "\n Neighborhood: " + destination.neighborhood;
        addressConfirmation += "\n Postal Code: " + destination.postcode;

        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text("Check Address"),
                content: Text(addressConfirmation),
                contentPadding: EdgeInsets.all(16),
                actions: [
                  FlatButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(color: Colors.red),
                      )),
                  FlatButton(
                      onPressed: () {
                        _saveRequest(destination);
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Accept",
                        style: TextStyle(color: Colors.green),
                      ))
                ],
              );
            });
      }
    }
  }

  _saveRequest(Destination destination) async {
    Usuario passenger = await UserFirebase.getDataLoggedUser();
    passenger.latitude = _localPassenger.latitude;
    passenger.longitude = _localPassenger.longitude;

    Request request = Request();
    request.destination = destination;
    request.passenger = passenger;
    request.status = StatusRequest.WAITING;
    //Salvar requisição
    Firestore db = Firestore.instance;
    db.collection("requests").document(request.id).setData(request.toMap());

    //Salvar requisição activa
    Map<String, dynamic> activeRequestData = {};
    activeRequestData["id_request"] = request.id;
    activeRequestData["id_user"] = passenger.idUser;
    activeRequestData["status"] = StatusRequest.WAITING;

    db
        .collection("active_requests")
        .document(passenger.idUser)
        .setData(activeRequestData);

    //Adicionar listener requisição
    if (_streamSubscriptionRequests == null) {
      _addRequestListener(request.id);
    }
  }

  _changeMainButton(String text, Color color, Function function) {
    setState(() {
      _buttonText = text;
      _buttonColor = color;
      _buttonFunction = function;
    });
  }

  _statusUberNotCalled() {
    _showDestinationAddressBox = true;
    _changeMainButton("Call Uber", Color(0xff1ebbd8), () {
      _callUber();
    });

    if (_localPassenger != null) {
      Position position = Position(
          latitude: _localPassenger.latitude,
          longitude: _localPassenger.longitude);
      _showPassengerMarker(position);
      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);
      _moveCamera(cameraPosition);
    }
  }

  _statusWaiting() {
    _showDestinationAddressBox = false;
    _changeMainButton("Cancel", Colors.red, () {
      _cancelUber();
    });

    double passengerLat = _requestData["passenger"]["latitude"];
    double passengerLon = _requestData["passenger"]["longitude"];

    Position position =
        Position(latitude: passengerLat, longitude: passengerLon);

    _showPassengerMarker(position);
    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);
    _moveCamera(cameraPosition);
  }

  _statusOnWay() {
    _showDestinationAddressBox = false;
    _changeMainButton("Driver on the way!", Colors.grey, () {});

    double destinationLatitude = _requestData["passenger"]["latitude"];
    double destinationLongitude = _requestData["passenger"]["longitude"];

    double originLatitude = _requestData["driver"]["latitude"];
    double originLongitude = _requestData["driver"]["longitude"];

    Marcador originMarker = Marcador(LatLng(originLatitude, originLongitude),
        "images/motorista.png", "Driver location");

    Marcador destinyMarker = Marcador(
        LatLng(destinationLatitude, destinationLongitude),
        "images/passageiro.png",
        "Destination location");

    _showTwoCenteredMarkers(originMarker, destinyMarker);
  }

  _statusTravel() {
    _showDestinationAddressBox = false;
    _changeMainButton("Traveling", Colors.grey, null);

    double destinationLatitude = _requestData["destination"]["latitude"];
    double destinationLongitude = _requestData["destination"]["longitude"];

    double originLatitude = _requestData["driver"]["latitude"];
    double originLongitude = _requestData["driver"]["longitude"];

    Marcador originMarker = Marcador(LatLng(originLatitude, originLongitude),
        "images/motorista.png", "Driver location");

    Marcador destinyMarker = Marcador(
        LatLng(destinationLatitude, destinationLongitude),
        "images/destino.png",
        "Destination location");

    _showTwoCenteredMarkers(originMarker, destinyMarker);
  }

  _showTwoCenteredMarkers(Marcador originMarker, Marcador destinyMarker) {
    double originLatitude = originMarker.local.latitude;
    double originLongitude = originMarker.local.longitude;

    double destinationLatitude = destinyMarker.local.latitude;
    double destinationLongitude = destinyMarker.local.longitude;

    _showTwoMarkers(originMarker, destinyMarker);

    //Southwest.latitude <= northeast.latitude é uma regra
    var nLat, nLon, sLat, sLon;
    if (originLatitude <= destinationLatitude) {
      sLat = originLatitude;
      nLat = destinationLatitude;
    } else {
      sLat = destinationLatitude;
      nLat = originLatitude;
    }

    if (originLongitude <= destinationLongitude) {
      sLon = originLongitude;
      nLon = destinationLongitude;
    } else {
      sLon = destinationLongitude;
      nLon = originLongitude;
    }

    _moveCameraBounds(LatLngBounds(
        northeast: LatLng(nLat, nLon), southwest: LatLng(sLat, sLon)));
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

    _changeMainButton("Total - \€ ${tripValueFormatted}", Colors.green, () {  });

    _markers = {};
    Position position = Position(latitude: destinationLatitude, longitude: destinationLongitude);

    _showMarker(position, "images/destino.png", "Destiny");

    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19
    );

    _moveCamera(cameraPosition);
  }

  _statusConfirmed() {
    if(_streamSubscriptionRequests != null) {
      _streamSubscriptionRequests.cancel();
    }
    _showDestinationAddressBox = true;
    _changeMainButton("Call Uber", Color(0xff1ebbd8), () {
      _callUber();
    });
    _requestData = {};
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

  _moveCameraBounds(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newLatLngBounds(latLngBounds, 100));
  }

  _showTwoMarkers(Marcador originMarker, Marcador destinyMarker) {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    LatLng latLngOrigin = originMarker.local;
    LatLng latLngDestiny = destinyMarker.local;

    Set<Marker> _markerList = {};
    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            originMarker.imagePath)
        .then((BitmapDescriptor icon) {
      Marker originM = Marker(
          markerId: MarkerId(originMarker.imagePath),
          position: LatLng(latLngOrigin.latitude, latLngOrigin.longitude),
          infoWindow: InfoWindow(title: originMarker.title),
          icon: icon);
      _markerList.add(originM);
    });

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            destinyMarker.imagePath)
        .then((BitmapDescriptor icon) {
      Marker destinyM = Marker(
          markerId: MarkerId(destinyMarker.imagePath),
          position: LatLng(latLngDestiny.latitude, latLngDestiny.longitude),
          infoWindow: InfoWindow(title: destinyMarker.title),
          icon: icon);
      _markerList.add(destinyM);
    });

    setState(() {  _markers = _markerList;  });
  }

  _cancelUber() async {
    FirebaseUser firebaseUser = await UserFirebase.getActualUser();
    Firestore db = Firestore.instance;

    db.collection("requests")
      .document(_idRequest)
      .updateData({"status": StatusRequest.CANCELED}).then((_) {
        db.collection("active_requests").document(firebaseUser.uid).delete();
    });
  }

  _recoverActiveRequest() async {
    FirebaseUser firebaseUser = await UserFirebase.getActualUser();
    Firestore db = Firestore.instance;
    DocumentSnapshot documentSnapshot =
        await db.collection("active_requests").document(firebaseUser.uid).get();

    if (documentSnapshot.data != null) {
      Map<String, dynamic> data = documentSnapshot.data;
      _idRequest = data["id_request"];
      _addRequestListener(_idRequest);
    } else {
      _statusUberNotCalled();
    }
  }

  _addRequestListener(String idRequest) async {
    Firestore db = Firestore.instance;
    _streamSubscriptionRequests = await db
        .collection("requests")
        .document(idRequest)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data != null) {
        Map<String, dynamic> data = snapshot.data;
        _requestData = data;
        String status = data["status"];
        _idRequest = data["id_request"];

        switch (status) {
          case StatusRequest.WAITING:
            _statusWaiting();
            break;
          case StatusRequest.ON_WAY:
            _statusOnWay();
            break;
          case StatusRequest.TRAVEL:
            _statusTravel();
            break;
          case StatusRequest.DONE:
            _statusDone();
            break;
          case StatusRequest.CONFIRMED:
            _statusConfirmed();
            break;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    //Adicionar um listener para requesição activa
    _recoverActiveRequest();

    //_recoverLastKnowPosition();
    _addListenerLocalization();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text("Passenger"),
          actions: [
            PopupMenuButton<String>(
                onSelected: _chooseMenuItem,
                itemBuilder: (context) {
                  return itensMenu.map((String item) {
                    return PopupMenuItem<String>(
                      value: item,
                      child: Text(item),
                    );
                  }).toList();
                })
          ],
        ),
        body: Container(
            child: Stack(children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _cameraPosition,
            onMapCreated: _onMapCreated,
            //myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
          ),
          Visibility(
            visible: _showDestinationAddressBox,
            child: Stack(
              children: [
                Positioned(
                    top: 0,
                    right: 0,
                    left: 0,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white),
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                              icon: Container(
                                margin: EdgeInsets.only(left: 20, bottom: 15),
                                width: 10,
                                height: 10,
                                child: Icon(Icons.location_on,
                                    color: Colors.green),
                              ),
                              hintText: "My position",
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.only(left: 15, top: 5)),
                        ),
                      ),
                    )),
                Positioned(
                    top: 55,
                    right: 0,
                    left: 0,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white),
                        child: TextField(
                          controller: _controllerDestination,
                          decoration: InputDecoration(
                              icon: Container(
                                margin: EdgeInsets.only(left: 20, bottom: 15),
                                width: 10,
                                height: 10,
                                child:
                                    Icon(Icons.local_taxi, color: Colors.black),
                              ),
                              hintText: "Type destination",
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.only(left: 15, top: 5)),
                        ),
                      ),
                    ))
              ],
            ),
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
                      onPressed: _buttonFunction)))
        ])));
  }

  @override
  void dispose() {
    super.dispose();
    _streamSubscriptionRequests.cancel();
  }
}
