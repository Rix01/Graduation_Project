import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class FileDetailsScreen extends StatefulWidget {
  final String recordingTitle;
  final int speakerCount;

  FileDetailsScreen({
    required this.recordingTitle,
    required this.speakerCount,
  });

  @override
  _FileDetailsScreenState createState() => _FileDetailsScreenState();
}

class _FileDetailsScreenState extends State<FileDetailsScreen> {
  late List<PlayerController> playerControllers;
  late List<bool> isPlayingList;
  int? selectedSpeakerIndex; // 선택된 화자의 인덱스를 저장할 변수 (선택되지 않았을 경우 null)
  late List<String> speakerSttList;

  @override
  void initState() {
    super.initState();
    initializeControllers();
    speakerSttList = List<String>.filled(widget.speakerCount, '');
    fetchSTTOutputs(widget.recordingTitle).then((sttOutputs) {
      setState(() {
        speakerSttList = sttOutputs;
      });
    }).catchError((error) => print('Error: $error'));
  }

  Future<void> initializeControllers() async {
    playerControllers = List.generate(
      widget.speakerCount,
      (index) => PlayerController(),
    );
    isPlayingList = List<bool>.filled(widget.speakerCount, false);

    // Firebase Storage에서 파일 다운로드하여 PlayerController에 전달
    for (int i = 0; i < widget.speakerCount; i++) {
      String fileName = 'output/${widget.recordingTitle}/result${i + 1}.wav';
      String downloadURL =
          await FirebaseStorage.instance.ref(fileName).getDownloadURL();
      /*String path =
          "/data/user/0/com.rollcake.firebase_example/cache/file_picker/StarWars3.wav"; */
      String localFilePath =
          await _downloadFile(downloadURL, 'result${i + 1}.wav');
      await playerControllers[i].preparePlayer(path: localFilePath);
    }
  }

  Future<String> _downloadFile(String url, String fileName) async {
    final http.Response response = await http.get(Uri.parse(url));
    final Directory tempDir = await getTemporaryDirectory();
    final File file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  void _playandPause(int index) async {
    for (int i = 0; i < widget.speakerCount; i++) {
      if (i == index) {
        isPlayingList[i] = !isPlayingList[i];
        if (isPlayingList[i]) {
          await playerControllers[i].startPlayer(finishMode: FinishMode.pause);
        } else {
          await playerControllers[i].pausePlayer();
        }
      } else {
        isPlayingList[i] = false;
        await playerControllers[i].pausePlayer();
      }
    }
    setState(() {});
  }

  // 선택한 부분부터 재생할 수 있도록
  void _seekTo(int index, double position) async {
    await playerControllers[index].seekTo(position as int);
  }

  // STT
  Future<List<String>> fetchSTTOutputs(String docId) async {
    List<String> sttOutputs = [];
    try {
      DocumentSnapshot<Map<String, dynamic>> docSnapshot =
          await FirebaseFirestore.instance
              .collection('audio_data')
              .doc(docId)
              .get();
      if (docSnapshot.exists) {
        Map<String, dynamic>? data = docSnapshot.data();
        if (data != null && data.containsKey('sttOutputs')) {
          sttOutputs = List<String>.from(data['sttOutputs']);
        }
      }
    } catch (e) {
      print('Error fetching STT outputs: $e');
    }
    return sttOutputs;
  }

  @override
  Widget build(BuildContext context) {
    // 화면의 전체 높이를 가져옴
    double screenHeight = MediaQuery.of(context).size.height;
    // 화면의 전체 너비를 가져옴
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.recordingTitle}',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: <Widget>[
          Flexible(
            flex: 6, // 전체 화면의 60%를 차지
            child: ListView(
              children: <Widget>[
                ...List.generate(widget.speakerCount, (index) {
                  return ListTile(
                    leading: IconButton(
                      icon: Icon(isPlayingList[index]
                          ? Icons.pause
                          : Icons.play_arrow),
                      onPressed: () => _playandPause(index),
                    ),
                    title: Text(
                      '화자 ${index + 1}',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: AudioFileWaveforms(
                      enableSeekGesture: true,
                      size: Size(MediaQuery.of(context).size.width, 60.0),
                      playerController: playerControllers[index],
                      decoration: BoxDecoration(
                        color: Colors.blue[300],
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        selectedSpeakerIndex = index; // 선택된 화자 인덱스 업데이트
                        // _fetchSpeakerContent(index);
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          // 하단 영역: 선택된 화자 정보 표시
          if (selectedSpeakerIndex != null)
            Container(
              height: screenHeight * 0.40, // 전체 화면의 40%를 차지
              width: screenWidth * 0.90,
              margin: EdgeInsets.all(15), // 여백 추가
              decoration: BoxDecoration(
                  color: Colors.blue[300],
                  borderRadius: BorderRadius.circular(20.0)),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Text(
                      '화자 ${selectedSpeakerIndex! + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.white),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        margin: EdgeInsets.only(
                            left: 20.0, right: 20.0, bottom: 20.0),
                        width: screenWidth * 0.8,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(10.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.5), // 그림자 색상
                              spreadRadius: 5,
                              blurRadius: 7,
                              offset: Offset(0, 3), // 그림자 위치 조정
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(20.0), // 내부 padding 설정,
                        child: Text(
                          //speakerContent ?? '', // speakerContent가 null이 아니면 표시
                          speakerSttList[selectedSpeakerIndex!],
                          style:
                              TextStyle(fontSize: 20, color: Colors.grey[700]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
