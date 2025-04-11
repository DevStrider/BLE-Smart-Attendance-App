import 'package:ble_smart_attendance_app/HomePage.dart';
import 'package:ble_smart_attendance_app/auth_service.dart';
import 'package:flutter/material.dart';
import 'WelcomePage.dart';
import 'app_loading_page.dart';

class AuthLayout extends StatelessWidget{

  const AuthLayout({
    super.key,
    this.pageIfNotConnected,
  });

  final Widget? pageIfNotConnected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: authService,
        builder: (context , authService , child){
          return StreamBuilder(
              stream: authService.authStateChanges,
              builder: (context, snapshot) {
                Widget widget;
                if(snapshot.connectionState == ConnectionState.waiting){
                  widget = const AppLoadingPage();
                } else if (snapshot.hasData){
                  widget = const HomePage();
                } else{
                  widget = pageIfNotConnected ?? const WelcomePage();
                }
                return widget;
              }
          );
        },
    );
  }
}