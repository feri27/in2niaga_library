import 'package:flutter/material.dart';
import 'package:in2niaga_library/in2niaga_library.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'IN2NIAGA PACKAGE TEST'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? result;

  Future<void> eyeBlink() async {
    final results = await availableCameras().then(
      (value) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FaceDetectionScreen(title: 'Liveness Detection', cameras: value),
        ),
      ),
    );
    if (results != null) {
      setState(() {
        result = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: eyeBlink,
              child: const SizedBox(
                height: 60.0,
                child: Card(
                  color: Colors.green,
                  child: Center(
                    child: Text('Liveness Detection',
                        style: TextStyle(
                            color: Colors.white, fontFamily: "Roboto")),
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            SizedBox(
                height: 200,
                width: 200,
                child: Text('Result: $result',
                    style: const TextStyle(
                      letterSpacing: 0.5,
                      color: Colors.black54,
                      fontFamily: "Roboto",
                      fontWeight: FontWeight.w600,
                    )))
          ],
        ),
      ),
    );
  }
}
