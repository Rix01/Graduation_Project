class FileItem {
  String fileName;  //파일 이름을 저장
  String conversionMethod;  //변환 방법 저장
  int speakerCount; //화자 수를 저장
  String language;  //언어 정보를 저장

  FileItem({  //생성자
    required this.fileName,
    required this.conversionMethod,
    required this.speakerCount,
    required this.language,
  });
}
