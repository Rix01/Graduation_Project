// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class AddData extends StatefulWidget {
  const AddData({super.key});

  @override
  State<AddData> createState() => _AddDataState();
}

class _AddDataState extends State<AddData> {
  String selectedLanguage = '한국어'; // 기본 선택 언어

  TextEditingController speakerNumController =
      TextEditingController(); // 텍스트 필드 컨트롤러

  DateTime currentTime = DateTime.now();

  addData(String input, String language, int speaker) async {
    FirebaseFirestore.instance.collection("audio_data").doc().set({
      "selecLang": language,
      "speakerNum": speaker,
      "uploadTime": currentTime, // 현재 시간을 업로드 시간으로 설정
    }).then(
      (value) {
        print("데이터가 전송되었습니다!");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Data"),
        centerTitle: true,
      ),
      body: Container(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            DropdownButton<String>(
              value: selectedLanguage,
              items: <String>['한국어', '영어'].map((String value) {
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
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.only(left: 25, right: 25),
              child: Column(
                children: [
                  SizedBox(
                    width: 100,
                    height: 40,
                    child: TextField(
                      controller: speakerNumController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '화자 수를 입력하세요',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 30),
                  ElevatedButton(
                    onPressed: () async {
                      // 음성 파일 경로 가져오기
                      FirebaseStorage storage = FirebaseStorage.instance;
                      final ref = storage.ref("input");
                      final listResult = await ref.list();

                      // 최근 업로드한 음성 파일 경로 얻기
                      final recentFileRef = listResult.items.first;
                      final recentFileURL =
                          await recentFileRef.getDownloadURL();
                      print("최근 파일 경로: $recentFileURL");

                      // 텍스트 필드에서 숫자 가져오기
                      int speakerNum = int.parse(speakerNumController.text);

                      addData(recentFileURL, selectedLanguage, speakerNum);

                      // 선택한 언어와 숫자 출력
                      print('선택한 언어: $selectedLanguage');
                      print('입력한 숫자: $speakerNum');
                    },
                    child: const Text("전송"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
