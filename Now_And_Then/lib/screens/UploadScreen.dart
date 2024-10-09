// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'FileItem.dart'; // 파일 아이템 모델을 import
import 'package:audio_waveforms/audio_waveforms.dart';

// 추가

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  String userInputFileName = ''; // 사용자가 입력한 파일명
  String conversionMethod = '화자 자동 분리';
  int conversionMethodNum = 1; // 넘겨줄 때는 정수로
  int speakerNum = 0;
  String selectedLanguage = '한국어';
  List<Widget> referenceButtons = []; // 레퍼런스 업로드 버튼 동적 생성 위한 리스트

  // 녹음 위해
  late final RecorderController recorderController;
  String? recordedFilePath; // 녹음된 파일의 경로를 저장하기 위한 변수
  bool isRecording = false; // 녹음 중인지 여부를 나타내는 변수

  // 레퍼런스 파일별 녹음 컨트롤러 및 경로 저장을 위한 리스트
  List<RecorderController> refControllers = [];
  List<String?> refRecordedPaths = [];
  List<bool> refIsRecording = [];

  // 업로드 이후 전송되게
  bool isFileUploaded = false; // 믹스 파일 업로드 되었는지
  int allRefsUploaded = 0; // 레퍼런스 파일 업로드 되었는지
  bool isRefUploaded = true;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 16000;
  }

  // 음성 파일 선택 위해 추가
  PlatformFile? file;

  // fileName, downloadURL, refName, currentTime 추가
  late String fileName, downloadURL, refName;
  late List<String> refNames = [];
  DateTime currentTime = DateTime.now();

  //
  Future<void> _showLoadingScreen(BuildContext context) async {
    bool isCompleted = false;

    await showDialog(
      context: context,
      barrierDismissible: false, // 사용자가 외부를 탭해도 닫히지 않도록 설정
      builder: (BuildContext context) {
        final StreamSubscription<DocumentSnapshot> subscription =
            FirebaseFirestore.instance
                .collection("audio_data")
                .doc(fileName)
                .snapshots()
                .listen((snapshot) {
          if (snapshot.exists && snapshot.data()?['outputNames'] != null) {
            setState(() {
              isCompleted = true;
            });
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          }
        });

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                SizedBox(height: 20),
                Text(
                  '음성 분리 중...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
//

  Future<void> _startRecording(int index) async {
    await refControllers[index].record();
    setState(() {
      refIsRecording[index] = true;
      refRecordedPaths[index] = null; // 녹음을 시작할 때 경로 초기화
    });
    print("레퍼런스 ${index + 1} 녹음 시작");
  }

  Future<void> _stopRecording(int index) async {
    final path = await refControllers[index].stop();
    setState(() {
      refIsRecording[index] = false;
      refRecordedPaths[index] = path; // 녹음 중지 후 경로 저장
    });
    print("레퍼런스 ${index + 1} 녹음 중지: $path");
    if (path != null) {
      // 파일 업로드
      print("레퍼런스 ${index + 1} 업로드 중: $path");
      // size 추가하라는데 default가 0이라고 함
      // 업로드 작업 생성!!
      refNames.add("ref${index + 1}" + ".m4a");
      await uploadRef(
          PlatformFile(name: "ref${index + 1}" + ".m4a}", path: path, size: 0),
          "ref${index + 1}" + ".m4a");
    }
  }

  // 음성 파일 녹음 버튼 추가
  Future<void> _startRecordingFile() async {
    await recorderController.record();
    setState(() {
      isRecording = true;
      recordedFilePath = null; // 녹음을 시작할 때 경로 초기화
    });
    print("음성 파일 녹음 시작");
  }

  Future<void> _stopRecordingFile() async {
    final path = await recorderController.stop();
    setState(() {
      isRecording = false;
      recordedFilePath = path; // 녹음 중지 후 경로 저장
    });
    print("음성 파일 녹음 중지: $path");
    if (path != null) {
      // 파일 업로드
      print("음성 파일 업로드 중: $path");
      print('업로드 파일 이름 : $userInputFileName');
      userInputFileName = userInputFileName + '.m4a';
      await uploadFile(
          PlatformFile(
            name: userInputFileName,
            path: path,
            size: 0,
          ),
          userInputFileName);
    }
  }

  void _playandPause(int index) async {
    if (index == speakerNum) {
      setState(() {
        isRecording = !isRecording;
      });
      if (isRecording) {
        await _startRecordingFile();
      } else {
        await _stopRecordingFile();
      }
    } else {
      setState(() {
        refIsRecording[index] = !refIsRecording[index];
      });
      if (refIsRecording[index]) {
        await _startRecording(index);
      } else {
        await _stopRecording(index);
      }
    }
  }

  // 레퍼런스 파일 업로드 버튼 동적 생성 위한 메서드
  List<Widget> updateReferenceButtons() {
    List<Widget> buttons = [];

    refControllers = List.generate(speakerNum, (index) {
      final controller = RecorderController()
        ..androidEncoder = AndroidEncoder.aac
        ..androidOutputFormat = AndroidOutputFormat.mpeg4
        ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
        ..sampleRate = 16000;
      return controller;
    });

    refRecordedPaths = List.generate(speakerNum, (index) => null);
    refIsRecording = List.generate(speakerNum, (index) => false);

    for (int i = 0; i < speakerNum; i++) {
      buttons.add(
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      // 레퍼런스 파일 가져오기
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.audio,
                      );
                      if (result != null) {
                        // 선택한 파일 처리
                        file = result.files.first;
                        print('파일 이름 : ${file!.name}');
                        print('파일 경로 : ${file!.path}');
                        // 업로드 작업 생성!!
                        refNames.add(
                            "ref${i + 1}" + ".${file!.name.split('.').last}");
                        await uploadRef(
                            file!,
                            "ref${i + 1}" +
                                ".${file!.name.split('.').last}"); // 파일명을 'ref1.(확장자)', 'ref2.(확장자)' 등으로 설정
                      } else {
                        // 파일 선택 취소
                      }
                    },
                    child: Text("레퍼런스 ${i + 1} 파일 선택"),
                  ),
                ),
                Text(
                  "    OR  ",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                IconButton(
                  icon: Icon(refIsRecording[i] ? Icons.stop : Icons.mic),
                  tooltip: refIsRecording[i] ? '녹음 중지' : '녹음 시작',
                  onPressed: () => _playandPause(i),
                ),
              ],
            ),
            // Add the waveform display widget
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: AudioWaveforms(
                enableGesture: true,
                size: Size(MediaQuery.of(context).size.width, 40.0),
                recorderController: refControllers[i],
                waveStyle: const WaveStyle(
                  waveColor: Colors.white,
                  extendWaveform: true,
                  showMiddleLine: false,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[300],
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('파일 업로드'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                decoration: InputDecoration(
                  labelText: '파일 이름을 입력하세요',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '파일명을 입력해주세요';
                  }
                  return null;
                },
                onChanged: (value) {
                  // 사용자가 입력한 파일명 저장
                  userInputFileName = value;
                },
                onSaved: (value) {
                  userInputFileName = value!;
                },
              ),
              // 일단 원래 있는 이름으로 업로드 하는 것으로 연결해놓음
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          // 업로드 관련 추가
                          onPressed: () async {
                            // 음성 파일 가져오기
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.audio,
                            );
                            if (result != null) {
                              // 선택한 파일 처리
                              file = result.files.first;
                              print('파일 이름 : ${file!.name}');
                              print('파일 경로 : ${file!.path}');

                              // 업로드 작업 생성!!
                              // + 사용자가 입력한 파일명을 사용하여 업로드
                              userInputFileName = userInputFileName +
                                  '.${file!.name.split('.').last}';
                              print('업로드 파일 이름 : $userInputFileName');
                              await uploadFile(file!, userInputFileName);
                            } else {
                              // 파일 선택 취소
                            }
                          },
                          child: const Text("음성 파일 선택"),
                        ),
                        Text(
                          "    OR  ",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        IconButton(
                          icon: Icon(isRecording ? Icons.stop : Icons.mic),
                          tooltip: isRecording ? '녹음 중지' : '녹음 시작',
                          onPressed: () => _playandPause(speakerNum),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: AudioWaveforms(
                        enableGesture: true,
                        size: Size(MediaQuery.of(context).size.width, 40.0),
                        recorderController: recorderController,
                        waveStyle: const WaveStyle(
                          waveColor: Colors.white,
                          extendWaveform: true,
                          showMiddleLine: false,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[300],
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextFormField(
                decoration: InputDecoration(
                  labelText: '화자 수를 입력하세요',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (conversionMethod == '화자 지정 분리' &&
                      (value == null ||
                          value.isEmpty ||
                          int.tryParse(value) == null ||
                          int.parse(value) <= 0)) {
                    return '올바른 화자 수를 입력해주세요';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    speakerNum = int.tryParse(value) ?? speakerNum;
                  });
                },
                onSaved: (value) {
                  setState(() {
                    speakerNum = int.tryParse(value!) ?? speakerNum;
                  });
                },
              ),
              // 화자 자동 분리를 1, 화자 지정 분리를 2로 놓고 받아야겠다
              // 화자 지정 분리의 경우에는 녹음 화면으로 넘어가야겠네
              DropdownButtonFormField(
                value: conversionMethod == '화자 자동 분리'
                    ? 1
                    : 2, // 지정된 값에 따라 int 값 다르게
                decoration: InputDecoration(labelText: '분리 방법'),
                items: [
                  DropdownMenuItem<int>(
                    value: 1,
                    child: Text('화자 자동 분리'),
                  ),
                  DropdownMenuItem<int>(
                    value: 2,
                    child: Text('화자 지정 분리'),
                  ),
                ],
                onChanged: (int? newValue) {
                  setState(() {
                    conversionMethod = newValue == 1 ? '화자 자동 분리' : '화자 지정 분리';
                    conversionMethodNum = newValue!;
                    if (conversionMethodNum == 2) {
                      isRefUploaded = false;
                      referenceButtons =
                          updateReferenceButtons(); // 화자 지정 분리일 때 버튼 생성
                    }
                  });
                },
              ),
              //지금 레퍼런스 파일 녹음 화면 아직 없으므로 그냥 업로드 하는 걸로 임시로 해놓음
              const SizedBox(height: 20),
              Column(
                children: referenceButtons,
              ),
              DropdownButtonFormField(
                value: selectedLanguage,
                decoration: InputDecoration(labelText: '언어 선택'),
                items: <String>['한국어', '영어', '일본어', '중국어']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedLanguage = newValue!;
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  // 버튼 가운데 위치
                  child: ElevatedButton(
                    // 업로드 관련 추가
                    onPressed: (isFileUploaded && isRefUploaded)
                        ? () async {
                            addData(selectedLanguage, speakerNum);

                            if (_formKey.currentState!.validate()) {
                              // 유효성 검사가 성공하면 저장 로직을 실행
                              _formKey.currentState!.save();

                              // 파일 정보를 객체로 만들어서 넘겨줌.
                              final newFile = FileItem(
                                fileName: fileName,
                                conversionMethod: conversionMethod,
                                speakerCount: speakerNum,
                                language: selectedLanguage,
                              );

                              await _showLoadingScreen(
                                  context); // 로딩 화면 표시 및 대기
                              Navigator.pop(context, newFile);
                            }
                          }
                        : null,
                    child: Text('전송'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> uploadFile(PlatformFile file, String userFileName) async {
    FirebaseStorage storage = FirebaseStorage.instance;
    Reference ref = storage.ref("input/$userFileName/$userFileName");

    // 원본 파일 이름 중복 체크
    fileName = userInputFileName;
    int count = 1;
    try {
      while (true) {
        await ref.getDownloadURL(); // 파일이 존재하는지 확인
        // 파일이 존재하면 파일 이름 변경
        fileName =
            '${userInputFileName.split('.').first}($count).${userInputFileName.split('.').last}';
        ref = storage.ref("input/$fileName/$fileName");
        count++;
      }
    } catch (e) {
      // 파일이 존재하지 않을 때 예외 처리
      print("파일이 존재하지 않습니다.");
    }

    try {
      //Task task = ref.putFile(File(file.path!));
      TaskSnapshot snapshot = await ref.putFile(File(file.path!));

      // 업로드 이후 Firestore에 파일 이름 추가
      // 업로드 완료 후 Firestore에 파일 정보 추가
      downloadURL = await snapshot.ref.getDownloadURL();

      print("믹스 파일 업로드 성공!!!!!");
      setState(() {
        isFileUploaded = true;
      });
    } catch (e) {
      print("파일 업로드 중 오류 발생: $e");
    }
  }

  // Ref Firebase Storage에 업로드
  Future<void> uploadRef(PlatformFile file, String reference) async {
    FirebaseStorage storage = FirebaseStorage.instance;
    Reference ref = storage.ref("ref/$fileName/${reference}");

    //Task task = ref.putFile(File(file.path!));
    TaskSnapshot snapshot = await ref.putFile(File(file.path!));

    // 업로드 완료
    //await task.whenComplete(() => print("업로드 성공!!!!!"));

    // 업로드 이후 Firestore에 파일 이름 추가
    // 업로드 완료 후 Firestore에 파일 정보 추가
    downloadURL = await snapshot.ref.getDownloadURL();

    //refNames.add(reference);

    print("업로드 성공!!!!!");
    allRefsUploaded += 1;
    if (allRefsUploaded == speakerNum) {
      setState(() {
        isRefUploaded = true;
      });
    }
  }

  addData(String language, int speaker) async {
    FirebaseFirestore.instance.collection("audio_data").doc(fileName).set({
      "fileName": fileName,
      "refMethod": conversionMethodNum,
      "refNames": refNames,
      "selecLang": language,
      "speakerNum": speaker,
      "uploadTime": currentTime, // 현재 시간을 업로드 시간으로 설정
      // 임시로 stt
      "sttOutputs": ['화자 1 stt', '화자 2 stt']
    }).then(
      (value) {
        print("데이터가 전송되었습니다!");
      },
    );
  }
}
