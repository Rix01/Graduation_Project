// import 'package:cloud_firestore/cloud_firestore.dart';

class SendAudio {
  String inputPath;
  String selecLang;
  int speakerNum;

  SendAudio({
    required this.inputPath,
    required this.selecLang,
    required this.speakerNum,
  });

  SendAudio.fromJson(Map<String, Object?> json)
      : this(
          inputPath: json['inputPath']! as String,
          selecLang: json['selecLang']! as String,
          speakerNum: json['speakerNum']! as int,
        );

  SendAudio copyWith({
    String? inputPath,
    String? selecLang,
    int? speakerNum,
  }) {
    return SendAudio(
        inputPath: inputPath ?? this.inputPath,
        selecLang: selecLang ?? this.selecLang,
        speakerNum: speakerNum ?? this.speakerNum);
  }

  Map<String, Object?> toJson() {
    return {
      'inputPath': inputPath,
      'selecLang': selecLang,
      'speakerNum': speakerNum,
    };
  }
}
