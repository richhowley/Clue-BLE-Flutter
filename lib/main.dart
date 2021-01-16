import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

/*

    Flutter/Dart example program, communicate with Adafruit Clue via BLE.

 */

// name the Clue advertises itself as
final String _clueAdvertiementName = 'CIRCUITPYbc57';

/*
      BleUart

      Read from and write to UART characteristics.
 */
class BleUart {

  BluetoothCharacteristic _txClue;
  BluetoothCharacteristic _rxClue;
  BluetoothService _uartService;
  StreamSubscription<List>  _rxRecieve;
  String _rxBuf = "";
  ValueNotifier<String> _rxIn = ValueNotifier<String>("");

  // getter for valueListenable to pick up RX reads
  get rxin { return _rxIn; }

  // use UART service to get TX and RX characteristics
  void setupUART(List<BluetoothService> services) {

    // find UART service
    _uartService = services.firstWhere((f) =>
      f.uuid.toString() == '6e400001-b5a3-f393-e0a9-e50e24dcca9e');

    // TX characteristic
    _txClue = _uartService.characteristics.firstWhere((f) =>
        f.uuid.toString().startsWith("6e400002"));

    // RX characteristic
    _rxClue = _uartService.characteristics.firstWhere((f) =>
        f.uuid.toString().startsWith("6e400003"));

    _rxClue.setNotifyValue(true); // notify when RX is written to

    // RX listener
    _rxRecieve = _rxClue.value.listen((value) {

      // byte array to string
      _rxBuf = utf8.decode(value);

      // set IN buffer for UI
      _rxIn.value  = _rxBuf ?? '';

      print(">>>>> RX:  $_rxBuf");

    });
  }

  // wrtie byte array to UART TX
  void _txWrite(val) async {

    _txClue.write(val);

  }

  // write string to UART
  void txWriteString(String str)
  {
    this._txWrite(utf8.encode(str));
  }

  // Clue has disconnected
  void disconnectUART()
  {
    // cancel subscription to RX
    if( _rxRecieve != null ) _rxRecieve.cancel();

    // clear message on UI
    _rxIn.value = '';

  }

}

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Clue BLE',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Clue BLE'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  final FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice clue;
  final clueUart = new BleUart();   // Clue UART
  StreamSubscription<BluetoothDeviceState>  watchState; // connection state change
  bool bleCpnnected = false;        // true if Clue is connected


  // make BLE connection to Clue
  Future<void> connectClue() async
  {

    // Listen to scan results
    flutterBlue.scanResults.listen((results) {

      // look for Clue
      for (ScanResult r in results) {

        if (r.device.name == _clueAdvertiementName) {

          // stop scanning
          flutterBlue.stopScan();

          // save device
          clue = r.device;

        } // if

      } // for

    });

    // kick off the scan
    flutterBlue.startScan(timeout: Duration(seconds: 4)).then((value) async {

      // if we found the Clue
      if( clue != null )
      {

        // listen for state change, only set once
        watchState ??= clue.state.listen((newState) async {

          // set connected flag
          setState(() {
            bleCpnnected = (newState == BluetoothDeviceState.connected);
          });

          // if the Clue disconnected
          if( newState == BluetoothDeviceState.disconnected )
            {

              // tell UART class we are disconnected
              clueUart.disconnectUART();

            } else {

              // get services then setup UART
              clue.discoverServices().then((services) => clueUart.setupUART(services));

            } // else

        });

        // connect
        clue.connect();


      } // if

    });

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
            Container(
              padding: EdgeInsets.all(8.0),
              // Connect Button
              child: FlatButton(
                color: Colors.green,
                textColor: Colors.white,
                disabledColor: Colors.grey,
                disabledTextColor: Colors.black,
                padding: EdgeInsets.all(8.0),
                splashColor: Colors.blueAccent,
                onPressed: bleCpnnected ? null : () { connectClue(); } ,
                child: Text(
                  "Connect",
                  style: TextStyle(fontSize: 20.0),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(8.0),
              // Disonnect Button
              child: FlatButton(
                color: Colors.red,
                textColor: Colors.white,
                disabledColor: Colors.grey,
                disabledTextColor: Colors.black,
                padding: EdgeInsets.all(8.0),
                splashColor: Colors.blueAccent,
                onPressed: bleCpnnected ? () { clue.disconnect(); } : null,
                child: Text(
                  "Disonnect",
                  style: TextStyle(fontSize: 20.0),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(8.0),
              // Send Text Button
              child: FlatButton(
                color: Colors.blue,
                textColor: Colors.white,
                disabledColor: Colors.grey,
                disabledTextColor: Colors.black,
                padding: EdgeInsets.all(8.0),
                splashColor: Colors.blueAccent,
                onPressed: bleCpnnected ? () { clueUart.txWriteString("Goodnight Moon"); } : null,
                child: Text(
                  "Send Text",
                  style: TextStyle(fontSize: 20.0),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.only(top: 20.0),
              child:
                  // Text echo, triggered by RX read
                  ValueListenableBuilder(
                    valueListenable: clueUart.rxin,
                    builder: (BuildContext context,  value, Widget child) {
                      return
                        Column(
                            children: <Widget>[
                              // label
                              Visibility(
                                visible: value.length > 0,
                                maintainSize: true,
                                maintainAnimation: true,
                                maintainState: true,
                                child: Text("Echo (count)",
                                  style: TextStyle(fontSize: 12.0)),
                              ),
                              // echo text
                              Text("$value",
                                  style: TextStyle(fontSize: 20.0, height: 1.5))
                          ]
                        );
                    },
                  )
            ),
          ],
        ),
      ),
    );
  }
}
