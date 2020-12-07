import 'package:flutter/material.dart';
import 'package:uber/screens/DriverScreen.dart';
import 'package:uber/screens/Home.dart';
import 'package:uber/screens/PassengerScreen.dart';
import 'package:uber/screens/Race.dart';
import 'package:uber/screens/Signup.dart';

class Routes {

  static Route<dynamic> routesGenerator (RouteSettings settings) {

    final args = settings.arguments;

    switch (settings.name) {
      case "/" :
        return MaterialPageRoute(
            builder: (_) => Home()
        );
      case "/signup" :
        return MaterialPageRoute(
            builder: (_) => Signup()
        );
      case "/driver-screen" :
        return MaterialPageRoute(
            builder: (_) => DriverScreen()
        );
      case "/passenger-screen" :
        return MaterialPageRoute(
            builder: (_) => PassengerScreen()
        );
      case "/race" :
        return MaterialPageRoute(
            builder: (_) => Race(args)
        );
      default:
        _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute () {
    return MaterialPageRoute(
        builder: (_) {
          return Scaffold(
            appBar: AppBar( centerTitle: true, title: Text("Screen not found!"),),
            body: Center(
              child: Text("Screen not found!")
            ),
          );
        }
    );
  }

}
