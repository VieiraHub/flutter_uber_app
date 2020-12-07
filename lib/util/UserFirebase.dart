import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uber/model/Usuario.dart';

class UserFirebase {

  static Future<FirebaseUser> getActualUser() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    return await auth.currentUser();
  }

  static Future<Usuario> getDataLoggedUser() async {
    FirebaseUser firebaseUser = await getActualUser();
    String idUser = firebaseUser.uid;
    
    Firestore db = Firestore.instance;
    DocumentSnapshot snapshot = await db.collection("users").document(idUser).get();
    Map<String, dynamic> data = snapshot.data;
    String userType = data["userType"];
    String email = data["email"];
    String name = data["name"];

    Usuario user = Usuario();
    user.idUser = idUser;
    user.userType = userType;
    user.email = email;
    user.name = name;
    return user;
  }

  static updateLocalizationData(String idRequest, double lat, double lon) async {
    Firestore db = Firestore.instance;
    Usuario driver = await getDataLoggedUser();
    driver.latitude = lat;
    driver.longitude = lon;
    
    db.collection("requests").document(idRequest).updateData({
      "driver" : driver.toMap()
    });
  }
}