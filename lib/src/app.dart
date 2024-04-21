import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter/services.dart';

import 'sample_feature/sample_item_details_view.dart';
import 'sample_feature/sample_item_list_view.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_view.dart';

/// The Widget that configures your application.
class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.settingsController,
  });

  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    // Glue the SettingsController to the MaterialApp.
    //
    // The ListenableBuilder Widget listens to the SettingsController for changes.
    // Whenever the user updates their settings, the MaterialApp is rebuilt.
    return ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          // Providing a restorationScopeId allows the Navigator built by the
          // MaterialApp to restore the navigation stack when a user leaves and
          // returns to the app after it has been killed while running in the
          // background.
          restorationScopeId: 'app',

          // Provide the generated AppLocalizations to the MaterialApp. This
          // allows descendant Widgets to display the correct translations
          // depending on the user's locale.
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''), // English, no country code
          ],

          // Use AppLocalizations to configure the correct application title
          // depending on the user's locale.
          //
          // The appTitle is defined in .arb files found in the localization
          // directory.
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context)!.appTitle,

          // Define a light and dark color theme. Then, read the user's
          // preferred ThemeMode (light, dark, or system default) from the
          // SettingsController to display the correct theme.
          theme: ThemeData(),
          darkTheme: ThemeData.dark(),
          themeMode: settingsController.themeMode,

          // Define a function to handle named routes in order to support
          // Flutter web url navigation and deep linking.
          onGenerateRoute: (RouteSettings routeSettings) {
            return MaterialPageRoute<void>(
              settings: routeSettings,
              builder: (BuildContext context) {
                switch (routeSettings.name) {
                  case SettingsView.routeName:
                    return SettingsView(controller: settingsController);
                  case SampleItemDetailsView.routeName:
                    return const SampleItemDetailsView();
                  case SampleItemListView.routeName:
                  default:
                    {
                      return RecordingPage();
                    }
                }
              },
            );
          },
        );
      },
    );
  }
}

class RecordingPage extends StatefulWidget {
  @override
  _RecordingPageState createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  bool _isRecording = false;
  File _savedRecording = File("/does_not_exist");
  String recordStatus = "Not recording";

  @override
  void dispose() {
    _audioRecorder.closeRecorder();
    super.dispose();
  }

  void _startRecording() async {
    try {
      if (!await requestAudioPermissions()) {
        print("Permissions not granted");
        return;
      }
      Directory tempDir = await getTemporaryDirectory();
      File filePath = File('${tempDir.path}/audio.wav');
      await _audioRecorder.openRecorder();
      await _audioRecorder.startRecorder(
        toFile: filePath.path,
        codec: Codec.pcm16WAV,
      );
      //await ScreenBrightness().setScreenBrightness(0.0);
      //await SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
      setState(() {
        recordStatus = "Recording...";
        _isRecording = true;
        _savedRecording = filePath;
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => BlackScreen()));
      });
    } catch (err) {
      print('Error starting recording: $err');
    }
  }

  void _stopRecording() async {
    try {
      await _audioRecorder.stopRecorder();
      setState(() {
        recordStatus = "Stopped recording";
        _isRecording = false;
      });
    } catch (err) {
      print('Error stopping recording: $err');
    }
    recordStatus = recordStatus;
  }

  void _analyzeRecording() async {
    print("Analyzing...");
    print("recording: $_savedRecording");

    if (!await _savedRecording.exists()) {
      print("No recording detected");
    } else {
      var url = Uri.parse('http://10.105.124.140:5000/upload_audio');
      var file = _savedRecording;
      var request = http.MultipartRequest('POST', url);
      var audioFile = await http.MultipartFile.fromPath('audio', file.path);
      request.files.add(audioFile);
      print("Analyzed!");
      recordStatus = "Sending...";
      try {
        print("sending");
        var response = await request.send();
        recordStatus = "Sent!";
        print("sent");
        if (response.statusCode == 200) {
          print("audio sent!");
          print(await response.stream.bytesToString());
        } else {
          print("failed to send audio data");
        }
      } catch (e) {
        recordStatus = "Error when sending request.";
        print("Error when sending request : $e");
      }
    }
    recordStatus = recordStatus;
  }

  Future<bool> requestAudioPermissions() async {
    if (await Permission.microphone.isDenied) {
      PermissionStatus status = await Permission.microphone.request();
      print('Microphone permission status: $status');
    }
    if (await Permission.manageExternalStorage.isDenied) {
      PermissionStatus status =
          await Permission.manageExternalStorage.request();
      print('Storage permission status: $status');
    }
    return await Permission.microphone.isGranted &&
        await Permission.manageExternalStorage.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keyboard Listener'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(recordStatus),
            // _isRecording ? Text('Recording...') : Text('Not recording'),
            const SizedBox(height: 20),
            FloatingActionButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: _isRecording ? Icon(Icons.stop) : Icon(Icons.mic),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: 200,
              child: FloatingActionButton(
                onPressed: _analyzeRecording,
                child: const Text("Analyze Recording"),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class BlackScreen extends StatefulWidget {
  const BlackScreen({super.key});

  @override
  State<BlackScreen> createState() => _BlackScreenState();
}

class _BlackScreenState extends State<BlackScreen> {
  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    ScreenBrightness().resetScreenBrightness();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ScreenBrightness().setScreenBrightness(0.0);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack, overlays: []);
    return SizedBox.expand(
      child: GestureDetector(
        child: Container(
          color: Colors.black,
        ),
        onDoubleTap: () => {Navigator.pop(context)},
      ),
    );
  }
}
