import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uber/model/Usuario.dart';


class Signup extends StatefulWidget {
  @override
  _SignupState createState() => _SignupState();
}

class _SignupState extends State<Signup> {

  TextEditingController _controllerName = TextEditingController();
  TextEditingController _controllerEmail = TextEditingController();
  TextEditingController _controllerPass = TextEditingController();
  bool _userType = false;
  String _errorMessage = "";

  _validateFields() {
    String name = _controllerName.text;
    String email = _controllerEmail.text;
    String pass = _controllerPass.text;

    if( name.isNotEmpty ) {
      if (email.isNotEmpty && email.contains("@")) {
        if (pass.isNotEmpty && pass.length > 6) {

          Usuario user = Usuario();
          user.name = name;
          user.email = email;
          user.pass = pass;
          user.userType = user.verifyUserType(_userType);

          _signupUser(user);

        } else {
          setState(() {  _errorMessage = "fill in the password, enter more than 6 digits";  });
        }
      } else {
        setState(() {  _errorMessage = "fill in the valid email";  });
      }
    } else {
      setState(() {  _errorMessage = "fill in the name";  });
    }
  }

  _signupUser(Usuario user) {
    FirebaseAuth auth = FirebaseAuth.instance;
    Firestore db = Firestore.instance;
    auth.createUserWithEmailAndPassword(
        email: user.email,
        password: user.pass
    ).then((firebaseUser) {
      db.collection("users").document( firebaseUser.user.uid ).setData( user.toMap() );

      switch (user.userType) {
        case "driver" :
          Navigator.pushNamedAndRemoveUntil(
              context, "/driver-screen", (_) => false
          );
          break;
        case "passenger" :
          Navigator.pushNamedAndRemoveUntil(
              context, "/passenger-screen", (_) => false
          );
          break;
        default :
          Navigator.pushNamedAndRemoveUntil(context, "/", (_) => false);

      }
    }).catchError((error) {
      _errorMessage = "Error to signup, check the fields and try again!";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Sign Up"),
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controllerName,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  style: TextStyle( fontSize: 20 ),
                  decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: "Full Name",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)
                      )
                  ),
                ),
                TextField(
                  controller: _controllerEmail,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle( fontSize: 20 ),
                  decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: "E-mail",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)
                      )
                  ),
                  // textAlign: TextAlign.center  Para centrar a hint
                ),
                TextField(
                  controller: _controllerPass,
                  obscureText: true,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle( fontSize: 20 ),
                  decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: "Password",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)
                      )
                  ),
                ),
                Padding(
                    padding: EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Text("passenger"),
                      Switch(
                          value: _userType,
                          onChanged: (bool value) {
                            setState(() {
                              _userType = value;
                            });
                          }
                      ),
                      Text("driver"),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 16, bottom: 10),
                  child: RaisedButton(
                      child: Text("SignUp",
                          style: TextStyle(color: Colors.white, fontSize: 20)
                      ),
                      color: Color(0xff1ebbd8),
                      padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      onPressed: () {
                        _validateFields();
                      }
                  ),
                ),
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
