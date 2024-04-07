import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;

class ChatPage extends StatefulWidget {
  final BluetoothDevice server;

  const ChatPage({required this.server});

  @override
  _ChatPage createState() => new _ChatPage();
}

class PredictionResponse {
  final String prediction;
  PredictionResponse(this.prediction);
}

class _Message {
  int whom;
  String text;
  _Message(this.whom, this.text);
}

class MessageData {
  String text;
  MessageData(
    this.text,
  );

  static List<String> temperature = List<String>.empty(growable: true);
  static List<String> soilMoisture = List<String>.empty(growable: true);
  static List<String> humidity = List<String>.empty(growable: true);
  static List<String> crop = List<String>.empty(growable: true);  

  Future<void> setData() async{
    List<String> data = this.text.split(" ");
    print(data);
    if (temperature.length < 10) {
      temperature.add(data[0]);
      humidity.add(data[1]);
      soilMoisture.add(data[2]);
      // 600-1000   23 - 30
      // scale this value from 600-1000 to 0-1 
      var x = double.parse(data[2]);
      x = (x - 600) / (1000 - 600);
      x = x * (300 - 20.02) + 20.02;
      String f = x.toStringAsFixed(2);
      print(f);
       final url = Uri.parse('http://192.168.29.55:8000/predict/');
       List<dynamic> listdata = ["93", "53", "83", "20", data[1], "7.069172227", f,data[2]];
      final response = await http.post(url, body: {
        'input_data': jsonEncode(listdata)
      });
      if (response.statusCode == 200) {
        String jsonResponse = response.body;
        Map<String, dynamic> parsedResponse = jsonDecode(jsonResponse);

  // Access the value of the "prediction" key
        String predictedCrop = parsedResponse['prediction'];

        print(predictedCrop); // Output: rice
        crop.add(predictedCrop);
      } else {
        print('Failed to make prediction');
      }
      
    } else {
      temperature.removeLast();
      soilMoisture.removeLast();
      humidity.removeLast();
      crop.removeLast();
      temperature.add(data[0]);
      humidity.add(data[1]);
      soilMoisture.add(data[2]);
      // make a prediction eith api
     
      final url = Uri.parse('http://192.168.29.55:8000/predict/');
       List<dynamic> listdata = ["93", "53", "83", data[0], data[1], "7.069172227", "290.6793783",data[2]];
      final response = await http.post(url, body: {
        'input_data': jsonEncode(listdata)
      });
      // decode the response
      if (response.statusCode == 200) {
         String jsonResponse = response.body;
        Map<String, dynamic> parsedResponse = jsonDecode(jsonResponse);

  // Access the value of the "prediction" key
        String predictedCrop = parsedResponse['prediction'];

        print(predictedCrop); // Output: rice
        crop.add(predictedCrop);
      } else {
        print('Failed to make prediction');
      }
      
    }
    // data.asMap().forEach((index, value) {
    //   debugPrint(index.toString() + " " + value);
    // });
  }

  static String getTemperature() {
    double mean = 0;
    temperature.forEach((element) {
      mean += double.parse(element);
    });
    mean = mean / temperature.length;
    return mean.toStringAsFixed(2);
  }

  static String getSoilMoisture() {
    double mean = 0;
    soilMoisture.forEach((element) {
      mean += double.parse(element);
    });
    mean = mean / soilMoisture.length;
    return mean.toStringAsFixed(2);
  }

  static String getHumidity() {
    double mean = 0;
    humidity.forEach((element) {
      mean += double.parse(element);
    });
    mean = mean / humidity.length;
    return mean.toStringAsFixed(2);
  }

  static String getCrop() {
    print("crop leleo");
    print(crop.last);
    return crop.last;
  }
}


class _ChatPage extends State<ChatPage> {
  static final clientID = 0;
  BluetoothConnection? connection;

  List<_Message> messages = List<_Message>.empty(growable: true);
  List<String> features = [
    'Temperature',
    'Humidity',
    'Soil Moisture',
    'Crop'
  ];
  String _messageBuffer = '';
  late String temp, hum, mosit, crop;
  late _ChartData chartData_;

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();

  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);

  bool isDisconnecting = false;

  @override
  void initState() {
    super.initState();

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      debugPrint('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });


      // connection!.input!.listen(_onDataReceived).onDone(() {
      //   if (isDisconnecting) {
      //     print('Disconnecting locally!');
      //   } else {
      //     print('Disconnected remotely!');
      //   }
      //   if (this.mounted) {
      //     // connection?.input!.listen(_onDataReceived);
      //     setState(() {});
      //   }
      // });

      connection!.input!.listen((data) {
  Timer(Duration(seconds: 5), () {
    _onDataReceived(data);
  });
}).onDone(() {
  if (isDisconnecting) {
    print('Disconnecting locally!');
  } else {
    print('Disconnected remotely!');
  }
  if (this.mounted) {
    setState(() {});
  }
});



      
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    messages.forEach((_message) {
      MessageData messageData = MessageData(_message.text.trim());
      // debugPrint(_message.text.trim());
      messageData.setData();
    });

    final GridView gridView = GridView.builder(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 5.0,
        mainAxisSpacing: 5.0,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Color.fromARGB(255, 150, 200, 244),
            borderRadius: BorderRadius.circular(30),
          ),
          // color: Colors.blue,
          child: grid(index, features),
          margin: const EdgeInsets.all(20),
        );
      },
    );

    final serverName = widget.server.name ?? "Unknown";

    return Scaffold(
      appBar: AppBar(
          title: (isConnecting
              ? Text('Connecting to ' + serverName + '...')
              : isConnected
                  ? Text('Connected with ' + serverName)
                  : Text('Chat log with ' + serverName))),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Flexible(
              child: Container(
                  padding: const EdgeInsets.all(12.0),
                  // controller: listScrollController,
                  child: gridView),
            ),
            Divider(),
            chartContainer("Temperature"),
            Row(
              children: <Widget>[
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.only(left: 16.0),
                    child: TextField(
                      style: const TextStyle(fontSize: 15.0),
                      controller: textEditingController,
                      decoration: InputDecoration.collapsed(
                        hintText: isConnecting
                            ? 'Wait until connected...'
                            : isConnected
                                ? 'Type your message...'
                                : 'Chat got disconnected',
                        hintStyle: const TextStyle(color: Colors.grey),
                      ),
                      enabled: isConnected,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(8.0),
                  child: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: isConnected
                          ? () => _sendMessage(textEditingController.text)
                          : null),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }


  void _onDataReceived(Uint8List data) {
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });

    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    // MessageData messageData;
    // debugPrint(dataString);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {
        print("hi");
        messages.clear();
        messages.add(
          _Message(
            1,
            backspacesCounter > 0
                ? _messageBuffer.substring(
                    0, _messageBuffer.length - backspacesCounter)
                : _messageBuffer + dataString.substring(0, index),
          ),
        );
        _messageBuffer = dataString.substring(index);
        // if (backspacesCounter > 0) {
        //   messageData = MessageData(_messageBuffer.substring(
        //       0, _messageBuffer.length - backspacesCounter));
        //   messageData.setData();
        // } else {
        //   messageData =
        //       MessageData(_messageBuffer + dataString.substring(0, index));
        //   messageData.setData();
        // }
      });
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
              0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
    }
  }

  void _sendMessage(String text) async {
    
    text = text.trim();
    textEditingController.clear();

    if (text.length > 0) {
      try {
        connection!.output.add(Uint8List.fromList(utf8.encode(text)));
        await connection!.output.allSent;

        // setState(() {
        // messages.add(_Message(clientID, text));
        // });

        Future.delayed(Duration(milliseconds: 333)).then((_) {
          listScrollController.animateTo(
              listScrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 333),
              curve: Curves.easeOut);
        });
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }

  Container chartContainer(String title) {
    DateTime now = DateTime.now();
    int counter = 0;
    List<_ChartData> liveChartData = List<_ChartData>.empty(growable: true);
    List<String> messageData_ = MessageData.temperature.toList();

    messageData_.forEach((e) {
      // String time = DateFormat('ss').format(now);
      if (counter >= 60) {
        counter = 0;
      }

      chartData_ = new _ChartData(e.toString(), (counter++).toString());
      liveChartData.add(
        chartData_,
      );
    });
    // debugPrint(liveChartData.);
    // liveChartData.forEach((element) {
    //   debugPrint(element.val.toString() + " " + element.time.toString());
    // });

    return Container(
      child: SfCartesianChart(
          primaryXAxis: CategoryAxis(),
          title: ChartTitle(text: title),
          // legend: Legend(isVisible: true),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <ChartSeries<_ChartData, String>>[
            LineSeries<_ChartData, String>(
              dataSource: liveChartData,
              xValueMapper: (_ChartData data_, _) => data_.time,
              yValueMapper: (_ChartData data_, _) => double.parse(data_.val),
              name: 'Celsius',
              dataLabelSettings: DataLabelSettings(isVisible: false),
            )
          ]),
    );
  }
}

class _ChartData {
  _ChartData(this.val, this.time);

  final String val;
  final String time;
}

Center grid(int index, List<String> features) {
  String featureName = features[index];
  String val = '0';
  switch (index) {
    case 0:
      String temp = MessageData.getTemperature();
      val = temp;
      break;
    case 1:
      String hum = MessageData.getHumidity();
      val = hum;
      break;
    case 2:
      String moist = MessageData.getSoilMoisture();
      val = moist;
      break;
    default:
      String z = MessageData.getCrop();
      print("");
      val = MessageData.getCrop();
  }
  return Center(
    child: Text(featureName + "\n" + val),
  );
}
