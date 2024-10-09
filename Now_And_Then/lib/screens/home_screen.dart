// ignore_for_file: avoid_print

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import 'dart:math';
import 'FileDetailsScreen.dart';
import 'UploadScreen.dart';
import 'FileItem.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FileItem> fileList = [];
  bool _showMore = false; //더보기 상태 관리를 위한 변수

  void _addFile(FileItem newFileItem) {
    setState(() {
      fileList.insert(0, newFileItem);
    });
  }

  // 실제 파이어베이스 storage에서도 삭제되는 로직 추가
  // input, ref, output에서 다 삭제하는 거 추가 완료
  void _deleteFile(int index) async {
    String fileNameToDelete = fileList[index].fileName; // 삭제할 파일의 이름 가져오기
    //print("삭제할 파일 이름 : $fileNameToDelete");
    try {
      // Firebase Storage에서 파일 삭제
      deleteFilesInDirectory("input/$fileNameToDelete");
      deleteFilesInDirectory("ref/$fileNameToDelete");
      deleteFilesInDirectory("output/$fileNameToDelete");

      // Firestore에서 파일 정보 삭제
      await deleteFileInfoFromFirestore(fileNameToDelete);
      setState(() {
        fileList.removeAt(index); // 리스트에서 삭제된 파일 제거
      });
      print('파일이 성공적으로 삭제되었습니다.');
    } catch (e) {
      print('파일 삭제 중 오류 발생: $e');
    }
  }

  // 디렉토리 내에 있는 파일 삭제 함수
  // 특정 디렉토리 내의 모든 파일 삭제 함수
  Future<void> deleteFilesInDirectory(String directoryPath) async {
    try {
      // 디렉토리 내의 파일 목록 가져오기
      final result =
          await FirebaseStorage.instance.ref(directoryPath).listAll();

      // 모든 파일을 순회하면서 삭제
      await Future.forEach(result.items, (Reference ref) async {
        await ref.delete(); // 파일 삭제
      });

      print('디렉토리 내의 모든 파일이 삭제되었습니다.');
    } catch (e) {
      print('디렉토리 내 파일 삭제 중 오류 발생: $e');
    }
  }

  // Firestore에서 파일 정보 삭제 함수
  Future<void> deleteFileInfoFromFirestore(String fileName) async {
    try {
      await FirebaseFirestore.instance
          .collection("audio_data")
          .doc(fileName)
          .delete();
      print('Firestore에서 파일 정보 삭제 완료');
    } catch (e) {
      print('Firestore 파일 정보 삭제 중 오류 발생: $e');
    }
  }

  // 검색 기능 메소드
  void _showSearchScreen() {
    TextEditingController _searchController = TextEditingController();
    String _searchText = "";

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Column(
                children: <Widget>[
                  // AppBar와 'X' 버튼 추가
                  AppBar(
                    title: Text('검색', textAlign: TextAlign.center),
                    leading: Container(), // AppBar의 기본 뒤로가기 버튼 숨김
                    centerTitle: true,
                    actions: <Widget>[
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(context); // 'X' 버튼을 누르면 모달을 닫음
                        },
                      ),
                    ],
                    elevation: 0, // AppBar의 그림자 제거
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "파일명을 입력하세요",
                        contentPadding: EdgeInsets.only(right: 30.0),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchText = value;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                        itemCount: fileList.length,
                        itemBuilder: (BuildContext context, int index) {
                          final fileItem = fileList[index];
                          //검색어를 포함하는 항목이 없을 때, 빈 화면 반환
                          if (_searchText.isNotEmpty &&
                              !fileItem.fileName
                                  .toLowerCase()
                                  .contains(_searchText.toLowerCase())) {
                            return Container();
                          } else {
                            // 검색어를 포함하지 않는 항목은 비어있는 ListTile 표시(위젯 자체는 생성)
                            return ListTile(
                              leading: Icon(Icons.play_arrow),
                              title: Text(fileList[index].fileName),
                              trailing: PopupMenuButton(
                                onSelected: (value) async {
                                  if (value == 'delete') {
                                    // 삭제 확인 다이얼로그 표시
                                    final confirmDelete =
                                        await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(
                                            '${fileList[index].fileName} 을(를) 삭제하시겠습니까?',
                                            style: TextStyle(fontSize: 15)),
                                        actions: <Widget>[
                                          ElevatedButton(
                                            child: Text('취소'),
                                            onPressed: () {
                                              Navigator.of(context).pop(
                                                  false); // 사용자가 취소를 선택하면 false 반환
                                            },
                                          ),
                                          ElevatedButton(
                                            child: Text('삭제'),
                                            onPressed: () {
                                              Navigator.of(context).pop(
                                                  true); // 사용자가 삭제를 선택하면 true 반환
                                            },
                                          ),
                                        ],
                                      ),
                                    );

                                    // 사용자가 '삭제'를 선택했다면 파일 삭제 실행
                                    if (confirmDelete ?? false) {
                                      // confirmDelete가 null이거나 true일 때
                                      _deleteFile(index);
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('파일 삭제'),
                                  ),
                                ],
                              ),
                              onTap: () {
                                // 녹음 세부 정보 화면으로 이동
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FileDetailsScreen(
                                      recordingTitle: fileList[index].fileName,
                                      speakerCount: fileList[index]
                                          .speakerCount, // 여기에 화자 수 정보를 전달
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                        }),
                  ),
                ],
              ),
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final int itemCount = _showMore
        ? fileList.length + 1
        : min(fileList.length, 5) + (fileList.length > 5 ? 1 : 0);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Now And Then',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 30,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: itemCount, // 수정: "더보기"/"간략히" 버튼 포함한 항목 수
              itemBuilder: (context, index) {
                //음성 파일이 최대 5개일 때
                if (index < min(fileList.length, 5)) {
                  return ListTile(
                    leading: Icon(Icons.play_arrow),
                    title: Text(fileList[index].fileName),
                    trailing: PopupMenuButton(
                      onSelected: (value) async {
                        if (value == 'delete') {
                          // 삭제 확인 다이얼로그 표시
                          final confirmDelete = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('해당 파일을 삭제하시겠습니까?',
                                  style: TextStyle(fontSize: 18)),
                              actions: <Widget>[
                                ElevatedButton(
                                  child: Text('취소'),
                                  onPressed: () {
                                    Navigator.of(context)
                                        .pop(false); // 사용자가 취소를 선택하면 false 반환
                                  },
                                ),
                                ElevatedButton(
                                  child: Text('삭제'),
                                  onPressed: () {
                                    Navigator.of(context)
                                        .pop(true); // 사용자가 삭제를 선택하면 true 반환
                                  },
                                ),
                              ],
                            ),
                          );

                          // 사용자가 '삭제'를 선택했다면 파일 삭제 실행
                          if (confirmDelete ?? false) {
                            // confirmDelete가 null이거나 true일 때
                            _deleteFile(index);
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('파일 삭제'),
                        ),
                      ],
                    ),
                    onTap: () {
                      FileDetailsScreen screen = FileDetailsScreen(
                        recordingTitle: fileList[index].fileName,
                        speakerCount: fileList[index].speakerCount,
                      );
                      // 여기에서 초기화 호출
                      // 녹음 세부 정보 화면으로 이동
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FileDetailsScreen(
                            recordingTitle: fileList[index].fileName,
                            speakerCount:
                                fileList[index].speakerCount, // 여기에 화자 수 정보를 전달
                          ),
                        ),
                      );
                    },
                  );
                }
                //더보기 버튼을 눌러 음성파일이 6개 이상일 때(반복되는 로직)
                else if (index < fileList.length && _showMore) {
                  // "더보기" 모드일 때 나머지 아이템들 가져옴
                  return ListTile(
                    leading: Icon(Icons.play_arrow),
                    title: Text(fileList[index].fileName),
                    trailing: PopupMenuButton(
                      onSelected: (value) async {
                        if (value == 'delete') {
                          // 삭제 확인 다이얼로그 표시
                          final confirmDelete = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('해당 파일을 삭제하시겠습니까?',
                                  style: TextStyle(fontSize: 18)),
                              actions: <Widget>[
                                ElevatedButton(
                                  child: Text('취소'),
                                  onPressed: () {
                                    Navigator.of(context)
                                        .pop(false); // 사용자가 취소를 선택하면 false 반환
                                  },
                                ),
                                ElevatedButton(
                                  child: Text('삭제'),
                                  onPressed: () {
                                    Navigator.of(context)
                                        .pop(true); // 사용자가 삭제를 선택하면 true 반환
                                  },
                                ),
                              ],
                            ),
                          );

                          // 사용자가 '삭제'를 선택했다면 파일 삭제 실행
                          if (confirmDelete ?? false) {
                            // confirmDelete가 null이거나 true일 때
                            _deleteFile(index);
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('파일 삭제'),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showMore = !_showMore;
                        });
                      },
                      child: Text(_showMore ? '간략히' : '더보기'),
                    ),
                  );
                }
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 20.0),
              child: ElevatedButton.icon(
                onPressed: () async {
                  // 파일 업로드 화면으로 이동
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => UploadScreen()),
                  );
                  if (result != null) {
                    _addFile(result);
                  }
                },
                icon: Icon(Icons.folder_open),
                label: Text('파일 업로드'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.search),
        onPressed: _showSearchScreen, // 검색 아이콘 클릭 시 검색 다이얼로그 표시
      ),
    );
  }
}
