// The original content is temporarily commented out to allow generating a self-contained demo - feel free to uncomment later.

// import 'package:flutter/material.dart';
// import 'package:frontend/src/rust/api/simple.dart';
// import 'package:frontend/src/rust/frb_generated.dart';
//
// Future<void> main() async {
//   await RustLib.init();
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: const Text('Bit-Link Miner Manager')),
//         body: Center(
//           child: FutureBuilder<String>(
//               future: greet(name: "Flutter"),
//               builder: (context, snapshot) {
//                 if (snapshot.hasData) {
//                   return Text(
//                     snapshot.data!,
//                     style: const TextStyle(fontSize: 24),
//                   );
//                 } else if (snapshot.hasError) {
//                   return Text('Error: ${snapshot.error}');
//                 } else {
//                   return const CircularProgressIndicator();
//                 }
//               }),
//         ),
//       ),
//     );
//   }
// }
//

import 'package:flutter/material.dart';
import 'package:frontend/src/rust/api/simple.dart';
import 'package:frontend/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
        body: Center(
          child: Text(
            'Action: Call Rust `greet("Tom")`\nResult: `${greet(name: "Tom")}`',
          ),
        ),
      ),
    );
  }
}
