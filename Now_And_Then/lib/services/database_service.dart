// Firestore collection 이름과 일치해야 함.
// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:NOW_AND_THEN/models/sendaudio.dart';

// ignore: constant_identifier_names
const String SENDAUDIO_COLLECTION_REF = "send_audios";

class DatabaseService {
  final _firestore = FirebaseFirestore.instance;

  late final CollectionReference _sendaudiosRef;

  DatabaseService() {
    _sendaudiosRef = _firestore
        .collection(SENDAUDIO_COLLECTION_REF)
        .withConverter<SendAudio>(
            fromFirestore: (snapshots, _) => SendAudio.fromJson(
                  snapshots.data()!,
                ),
            toFirestore: (sendaudio, _) => sendaudio.toJson());
  }

  Stream<QuerySnapshot> getSendAudios() {
    return _sendaudiosRef.snapshots();
  }

  Future<void> saveAudioInfo({
    required String inputPath,
    required String selecLang,
    required int speakerNum,
  }) async {
    try {
      await _sendaudiosRef.add({
        'inputPath': inputPath,
        'selecLang': selecLang,
        'speakerNum': speakerNum,
      });
    } catch (e) {
      print('Error saving audio info: $e');
    }
  }

  void addSendAudio(SendAudio sendaudio) async {
    _sendaudiosRef.add(sendaudio);
  }
}
