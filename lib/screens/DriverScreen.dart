import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uber/util/StatusRequest.dart';
import 'package:uber/util/UserFirebase.dart';


class DriverScreen extends StatefulWidget {
  @override
  _DriverScreenState createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {

  List<String> itensMenu = ["Settings", "Logout"];
  final _controller = StreamController<QuerySnapshot>.broadcast();
  Firestore db = Firestore.instance;

  _logoutUser() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    await auth.signOut();
    Navigator.pushReplacementNamed(context, "/");
  }

  _chooseMenuItem(String choose) {
    switch(choose) {
      case "Logout" :
        _logoutUser();
        break;
      case "Settings" :
        break;
    }
  }

  Stream<QuerySnapshot> _addListenerRequests() {
    final stream = db.collection("requests")
        .where("status", isEqualTo: StatusRequest.WAITING).snapshots();

    stream.listen((data) {  _controller.add(data);  });
  }

  _recoverDriverActiveRequest() async {
    //Recuperar dados do useuario loggado
    FirebaseUser firebaseUser = await UserFirebase.getActualUser();
    //Recuperar requisição activa
    DocumentSnapshot documentSnapshot = await db
        .collection("active_driver_request").document(firebaseUser.uid).get();

    var requestData = documentSnapshot.data;
    if (requestData == null) {
      _addListenerRequests();
    } else {
      String idRequest = requestData["id_request"];
      Navigator.pushReplacementNamed(context, "/race", arguments: idRequest);
    }
  }

  @override
  void initState() {
    super.initState();
    //Recupera requisição activa para verificar se motorista está
    //atendendo alguma requisição e envia-o para a tela de corrida
    _recoverDriverActiveRequest();
  }


  @override
  Widget build(BuildContext context) {

    var loadingMessage = Center(
      child: Column(
        children: [
          Text("Loading requests"),
          CircularProgressIndicator()
        ]
      )
    );

    var noDataMessage = Center(
        child: Text("You have no requests",
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold)
        )
    );



    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text("Driver"),
          actions: [
            PopupMenuButton<String>(
                onSelected: _chooseMenuItem,
                itemBuilder: (context) {
                  return itensMenu.map((String item) {

                    return PopupMenuItem<String> (
                      value: item,
                      child: Text(item),
                    );
                  }).toList();
                }
            )
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _controller.stream,
            // ignore: missing_return
            builder: (context, snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                return loadingMessage;
                break;
              case ConnectionState.active:
              case ConnectionState.done:

                if(snapshot.hasError) {
                  return Text("Error loading data!");
                } else {
                  QuerySnapshot querySnapshot = snapshot.data;
                  if ( querySnapshot.documents.length == 0 ) {
                    return noDataMessage;
                  } else {
                    return ListView.separated(
                      itemCount: querySnapshot.documents.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 2,
                        color: Colors.grey,
                      ),
                      itemBuilder: (context, index) {
                        List<DocumentSnapshot> requests = querySnapshot.documents.toList();
                        DocumentSnapshot item = requests[index];
                        String idRequest = item["id"];
                        String passegerName = item["passenger"]["name"];
                        String street = item["destination"]["street"];
                        String number = item["destination"]["number"];
                        return ListTile(
                          title: Text(passegerName),
                          subtitle: Text("Destination: $street, $number"),
                          onTap: ( ){  Navigator.pushNamed(context, "/race", arguments: idRequest);  },
                        );
                      }
                    );
                  }
                }
                break;
            }
            }
        )
    );
  }
}
