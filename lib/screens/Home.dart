import 'package:flutter/material.dart';
import 'package:uber/model/Usuario.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  TextEditingController _controllerEmail = TextEditingController(text: "vieira@gmail.com");
  TextEditingController _controllerPass = TextEditingController(text: "123456789");
  String _errorMessage = "";
  bool _loading = false;

  _validateFields() {
    String email = _controllerEmail.text;
    String pass = _controllerPass.text;

    if (email.isNotEmpty && email.contains("@")) {
      if (pass.isNotEmpty && pass.length > 6) {
        Usuario user = Usuario();
        user.email = email;
        user.pass = pass;

        _loginUser(user);
      } else {
        setState(() {  _errorMessage = "fill in the password, enter more than 6 digits";  });
      }
    } else {
      setState(() {  _errorMessage = "fill in the valid email";  });
    }
  }

  _loginUser(Usuario user) {

    setState(() {  _loading = true;  });
    FirebaseAuth auth = FirebaseAuth.instance;
    auth.signInWithEmailAndPassword(email: user.email, password: user.pass)
        .then((firebaseUser) {
          _redirectScreenForUserType(firebaseUser.user.uid);
    }).catchError((error) {
      _errorMessage = "Error to login, check e-mail and password again!";
    });
  }

  _redirectScreenForUserType(String idUser) async {
    Firestore db = Firestore.instance;
    DocumentSnapshot snapshot = await db.collection("users").document(idUser).get();
    Map<String, dynamic> data = snapshot.data;
    String userType = data["userType"];

    setState(() {  _loading = false;  });

    switch(userType){
      case "driver" :
        Navigator.pushReplacementNamed(  context, "/driver-screen"  );
        break;
      case "passenger" :
        Navigator.pushReplacementNamed(  context, "/passenger-screen"  );
        break;
    }
  }

  _verifyUserLogged() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseUser loggedUser = await auth.currentUser();
    if(loggedUser != null) {
      String idUser = loggedUser.uid;
      _redirectScreenForUserType(idUser);
    }
  }

  @override
  void initState() {
    super.initState();
    _verifyUserLogged();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("images/fundo.png"), fit: BoxFit.cover)),
        padding: EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child: Image.asset("images/logo.png",
                        width: 200, height: 150)),
                TextField(
                  controller: _controllerEmail,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: "E-mail",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6))),
                  // textAlign: TextAlign.center  Para centrar a hint
                ),
                TextField(
                  controller: _controllerPass,
                  obscureText: true,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: "Password",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6))),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 16, bottom: 10),
                  child: RaisedButton(
                      child: Text("Login",
                          style: TextStyle(color: Colors.white, fontSize: 20)),
                      color: Color(0xff1ebbd8),
                      padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      onPressed: () {
                        _validateFields();
                      }),
                ),
                Center(
                  child: GestureDetector(
                    child: Text(
                      "Don't have account? Sign up!",
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, "/signup");
                    },
                  ),
                ),
                _loading ? Center( child: CircularProgressIndicator(backgroundColor: Colors.white,)) : Container(),
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red, fontSize: 20),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
