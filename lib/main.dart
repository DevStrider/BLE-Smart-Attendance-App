import 'package:flutter/material.dart';


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .primary,
        title: const Text(
          'Attendance assistance',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            // TODO: Implement menu functionality
            print('Menu button pressed');
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Hi! Welcome',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // TODO: Add login fields or user name display here
              // Example for login fields:
              /*
              const TextField(
                decoration: InputDecoration(labelText: 'Username'),
              ),
              const TextField(
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: () {
                // TODO: Implement login logic
                print('Login button pressed');
              }, child: const Text('Login')),
              */
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement logout functionality
                  print('Logout button pressed');
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
      // TODO: Consider adding a BottomNavigationBar here later
      // bottomNavigationBar: BottomNavigationBar(
      //   items: const [
      //     BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      //     // Add other navigation items
      //   ],
      // ),
    );
  }
}