// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:monitor_app/constants/constants.dart';
import 'package:monitor_app/screens/route1.dart';
import 'package:monitor_app/screens/route2.dart';
import 'package:mqtt_client/mqtt_client.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var pongCount = 0; // Pong counter

  bool error = false;

  void setupMQTT() async {
    /// A websocket URL must start with ws:// or wss:// or Dart will throw an exception, consult your websocket MQTT broker
    /// for details.
    /// To use websockets add the following lines -:
    /// client.useWebSocket = true;
    /// client.port = 80;  ( or whatever your WS port is)
    /// There is also an alternate websocket implementation for specialist use, see useAlternateWebSocketImplementation
    /// Note do not set the secure flag if you are using wss, the secure flags is for TCP sockets only.
    /// You can also supply your own websocket protocol list or disable this feature using the websocketProtocols
    /// setter, read the API docs for further details here, the vast majority of brokers will support the client default
    /// list so in most cases you can ignore this.

    try {
      /// Set logging on if needed, defaults to off
      client.logging(on: true);

      /// Set the correct MQTT protocol for mosquito
      client.setProtocolV311();

      // /// The connection timeout period can be set if needed, the default is 5 seconds.
      client.connectTimeoutPeriod = 30000; // milliseconds

      client.keepAlivePeriod = 10; // seconds

      /// Add the unsolicited disconnection callback
      client.onDisconnected = onDisconnected;

      /// Add the successful connection callback
      client.onConnected = onConnected;

      /// Add a subscribed callback, there is also an unsubscribed callback if you need it.
      /// You can add these before connection or change them dynamically after connection if
      /// you wish. There is also an onSubscribeFail callback for failed subscriptions, these
      /// can fail either because you have tried to subscribe to an invalid topic or the broker
      /// rejects the subscribe request.
      client.onSubscribed = onSubscribed;

      /// Set a ping received callback if needed, called whenever a ping response(pong) is received
      /// from the broker.
      client.pongCallback = pong;

      /// Create a connection message to use or use the default one. The default one sets the
      /// client identifier, any supplied username/password and clean session,
      /// an example of a specific one below.
      final connMess = MqttConnectMessage()
          .withClientIdentifier('Mqtt_MyClientUniqueId')
          .startClean() // Non persistent session for testing
          .withProtocolName("MQTT")
          .withWillQos(MqttQos.atMostOnce);
      print('EXAMPLE::Mosquitto client connecting....');
      client.connectionMessage = connMess;

      /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
      /// in some circumstances the broker will just disconnect us, see the spec about this, we however will
      /// never send malformed messages.
      try {
        await client.connect();
        setState(() {
          error = false;
        });
      } on NoConnectionException catch (e) {
        // Raised by the client when connection fails.
        print('EXAMPLE::client exception - $e');
        client.disconnect();
        setState(() {
          error = true;
        });
      } on SocketException catch (e) {
        // Raised by the socket layer
        print('EXAMPLE::socket exception - $e');
        client.disconnect();
        setState(() {
          error = true;
        });
      }

      /// Check we are connected
      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        print('EXAMPLE::Mosquitto client connected');
        setState(() {
          error = false;
        });
      } else {
        /// Use status here rather than state if you also want the broker return code.
        print('EXAMPLE::ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}');
        setState(() {
          error = true;
        });
        client.disconnect();
      }

      /// Ok, lets try a subscription
      print('EXAMPLE::Subscribing to the test_topic');
      const topic = 'test_topic'; // Not a wildcard topic
      client.subscribe(topic, MqttQos.atMostOnce);

      /// The client has a change notifier object(see the Observable class) which we then listen to to get
      /// notifications of published updates to each subscribed topic.
      client.updates!.listen(onMessage);

      /// If needed you can listen for published messages that have completed the publishing
      /// handshake which is Qos dependant. Any message received on this stream has completed its
      /// publishing handshake with the broker.
      client.published!.listen((MqttPublishMessage message) {
        print('EXAMPLE::Published notification:: topic is ${message.variableHeader!.topicName}, with Qos ${message.header!.qos}');
        print("Message is : $message");
      });
    } catch (ex) {
      setState(() {
        error = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    setupMQTT();
  }

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Navigator(
            key: navigatorKey,
            onGenerateRoute: (settings) {
              Widget? selectedRoute;
              if (settings.name == Route1.routeName) {
                selectedRoute = const Route1();
              } else if (settings.name == Route2.routeName) {
                selectedRoute = const Route2();
              }
              return MaterialPageRoute(builder: (ctx) {
                return selectedRoute ?? const Route1();
              });
            },
            initialRoute: '/',
          ),
          if (error)
            Container(
              alignment: Alignment.center,
              color: Colors.black12,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Error Occurred"),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        error = false;
                      });
                      setupMQTT();
                    },
                    child: const Text(
                      "Retry",
                    ),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The subscribed callback
  void onSubscribed(String topic) {
    print('EXAMPLE::Subscription confirmed for topic $topic');
  }

  /// The unsolicited disconnect callback
  void onDisconnected() {
    print('EXAMPLE::OnDisconnected client callback - Client disconnection');
    if (client.connectionStatus!.disconnectionOrigin == MqttDisconnectionOrigin.solicited) {
      print('EXAMPLE::OnDisconnected callback is solicited, this is correct');
    } else {
      print('EXAMPLE::OnDisconnected callback is unsolicited or none, this is incorrect - exiting');
      exit(-1);
    }
    if (pongCount == 3) {
      print('EXAMPLE:: Pong count is correct');
    } else {
      print('EXAMPLE:: Pong count is incorrect, expected 3. actual $pongCount');
    }
  }

  /// The successful connect callback
  void onConnected() {
    print('EXAMPLE::OnConnected client callback - Client connection was successful');
  }

  /// Pong callback
  void pong() {
    // print('EXAMPLE::Ping response client callback invoked');
    pongCount++;
  }

  void onMessage(List<MqttReceivedMessage<MqttMessage?>>? c) {
    final recMess = c![0].payload as MqttPublishMessage;
    final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

    navigatorKey.currentState?.pushNamed(pt);

    print("Message: $pt");
  }
}
