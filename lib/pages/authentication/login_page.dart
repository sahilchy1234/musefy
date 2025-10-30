import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class LoginPage extends StatefulWidget{
  const LoginPage({super.key});
  
@override
State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>{

  final TextEditingController emailController =  TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  bool isLoading = false;

  void login() {

    setState(() => isLoading = true);
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login successful (demo)")),
      );
    });
  }


}
