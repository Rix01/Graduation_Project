from flask import Blueprint, request, jsonify

userAPI = Blueprint('userAPI', __name__)

@userAPI.route('/triggered', methods=['POST'])
def triggered():
    # 요청의 JSON 본문을 파싱합니다.
    data = request.json

    # 파일 이름이자 문서 이름
    fd_name = data.get('fileName')

    if fd_name:
        # 파일 이름이 있으면 터미널 창에 출력
        print("Firestore 트리거 발생!")
        print(f"받은 파일 이름: {fd_name}")
        # 모델 코드 실행
        run_model(fd_name)
        # 성공적으로 처리되었음을 나타내는 HTTP 응답을 반환
        return jsonify({"message": "데이터를 성공적으로 받았습니다."}), 200
    else:
        # 'fileName' 키가 없으면 오류 메시지와 함께 HTTP 응답을 반환
        return jsonify({"error": "fileName이 누락되었습니다."}), 400


############# 코랩 코드 #######################
def run_model(fd_name):
    global ref_name, file_name, speaker_num, ref_names, ref_method, selec_lang
    from firebase_admin import firestore
    import os
    from google.cloud import storage

    # 인증 파일 경로 설정
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "api/key.json"

    # Storage 클라이언트 초기화
    storage_client = storage.Client()

    # Bucket 이름 설정
    bucket_name = "example-6daae.appspot.com"
    bucket = storage_client.bucket(bucket_name)

    db = firestore.client()

    # 컬렉션에서 문서 select
    doc_name = db.collection('audio_data').document(fd_name)
    doc = doc_name.get()
    # 컬렉션에서 문서 필드값 중 파일명, 변환 방법, 화자 수, 레퍼런스명, 언어 가져오기
    if doc.exists:
        data = doc.to_dict()
        file_name = data['fileName']  # 문서의 fileName 필드값
        ref_method = data['refMethod']  # 문서의 refMethod 필드값
        speaker_num = data['speakerNum']    # 문서의 speakerNum 필드값
        if(ref_method == 2):
            ref_names = data['refNames']    # 문서의 refName 필드값
            print("ref_names >> ")
            # ref_names 배열에서 각 요소 출력
            for ref_name in ref_names:
                print(ref_name)
        selec_lang = data['selecLang']  # 문서의 selecLang 필드값

        print(f"file_name : {file_name}")
        print(f"ref_method : {ref_method}")
        print(f"speaker_num : {speaker_num}")
        print(f"selec_lang : {selec_lang}")
    else:
        print('문서가 존재하지 않습니다')

    # 파일 디렉토리 추가
    if not os.path.exists(f"store/input/{fd_name}"):
        os.makedirs(f"store/input/{fd_name}")
    if not os.path.exists(f"store/ref/{fd_name}"):
        os.makedirs(f"store/ref/{fd_name}")
    if not os.path.exists(f"store/output/{fd_name}"):
        os.makedirs(f"store/output/{fd_name}")

    ##### 다운로드될 input, ref, output 파일이 저장될 경로 지정
    local_file_path = f"store/input/{fd_name}/{file_name}"
    # ref_names 배열에서 각 요소를 사용하여 경로 생성
    local_ref_paths = []
    for idx in range(speaker_num):
        local_ref_path = f"store/ref/{fd_name}/ref{idx+1}.wav"
        local_ref_paths.append(local_ref_path)
    local_output_path = f"store/output/{fd_name}"
    local_enhanced_output_path = f"store/output/{fd_name}/enhanced"  # enhanced

    # pyrebase >> blob 변경
    try:
        blob = bucket.blob(f"input/{fd_name}/{file_name}")
        blob.download_to_filename(local_file_path)

        if(ref_method == 2):
            # ref_names 배열을 순회하여 각 ref에 대해 다운로드
            for idx in range(speaker_num):
                blob = bucket.blob(f"ref/{fd_name}/{ref_names[idx]}")
                blob.download_to_filename(local_ref_paths[idx])

    except Exception as e:
        print(f"Error downloading file: {e}")
        return jsonify({"error": str(e)}), 500

    ####################################################################
    stt_outputs = []
    # 모델 실행 (1은 자동, 2는 지정)
    if(ref_method == 1):
        stt_outputs = fb_connect1(speaker_num, local_file_path, local_output_path, selec_lang)
    elif(ref_method == 2):
        stt_outputs = fb_connect2(speaker_num, local_file_path, local_ref_paths, local_output_path, selec_lang)

    output_names = []
    #stt_paths = []
    for idx in range(speaker_num):
        upload_path = f"output/{fd_name}/result{idx+1}.wav"
        #stt_paths.append(f"gs://{bucket_name}/{upload_path}")
        blob = bucket.blob(upload_path)
        output_name = f"result{idx+1}.wav"
        output_names.append(output_name)

        with open(f"{local_enhanced_output_path}/result{idx+1}.wav", "rb") as f:
            blob.upload_from_file(f)

    doc_name.update({"outputNames":output_names})
    doc_name.update({"sttOutputs":stt_outputs})
    print('Firestore 데이터베이스 업데이트 완료')

    # stt 여기?

    """from stt.stt_func import transcribe_file
    stt_results = []
    language = "ko-KR" if selec_lang == '한국어' else "en-US"

    for stt_path in stt_paths:
        print(stt_path)
        stt_results.append(transcribe_file(stt_path,language))
    print(stt_results)"""




# 자동 변환(다이어라이저 사용)
def fb_connect1(sn, mix_path, output_path,lang):
    import os
    from google.cloud import storage
    from vf_run import main, main_multi, Info
    from ch_refer.refer_func import convert_to_mono_16k, refer_diarizer, refer_output
    from change_file_extension import change_file_extension

    My_info = Info()
    # ================================ 입력 파일
    input_file = mix_path

    # 오디오 파일 전처리 때문에 저장하는 파일명(로컬에 저장됨)
    file_path, file_extension = input_file.rsplit('.', 1)
    WAV_FILE = f"{file_path}_mono.{file_extension}"  # 파일명

    # ================================= 코드 실행

    convert_to_mono_16k(input_file, WAV_FILE)  # 파일 변환
    signal, fs, segments = refer_diarizer(WAV_FILE, sn)  # 추출
    My_info.refers = refer_output(segments, signal, fs)  # 추출된것 저장해서 경로 받음


    os.environ['KMP_DUPLICATE_LIB_OK'] = 'True'

    #My_info.mix = mix_path
    My_info.mix = change_file_extension(mix_path)  # 확장자 변경
    My_info.output = output_path

    My_info.config = "voicefilter/config/config.yaml"
    My_info.embedded = "voicefilter/embedder.pt"
    My_info.chkpt = "D:/chkpt/my_model0330_2/chkpt_803000.pt"

    # main(My_info) # 단일

    My_info.num = sn
    # My_info.refers = ["voicefilter/ref1.wav", "voicefilter/ref2.wav"]
    main_multi(My_info)  # 멀티

    # ------------------------ stt
    from stt.stt_func import convert_to_mono_wav,transcribe_file, enhanced_file,stt_speech

    stt_result = []
    language = "ko-KR" if lang == '한국어' else "en-US"

    for filename in os.listdir(output_path):
        # 파일 경로 생성
        file_path = os.path.join(output_path, filename)
        # 파일이 실제 파일인지 확인
        if os.path.isfile(file_path):
            convert_to_mono_wav(file_path)
            enhanced_output_path = enhanced_file(file_path)
            stt_result.append(stt_speech(enhanced_output_path, language))
    return stt_result


# 지정 변환(다이어라이저 없이)
# sn은 speakerNum
def fb_connect2(sn, mix_path, ref_paths, output_path, lang):
    import os
    from google.cloud import storage
    from vf_run import main, main_multi, Info
    from change_file_extension import change_file_extension

    My_info = Info()

    os.environ['KMP_DUPLICATE_LIB_OK'] = 'True'

    My_info.mix = change_file_extension(mix_path) #확장자 변경
    for i in range(len(ref_paths)):
        ref_paths[i] = change_file_extension(ref_paths[i])
    My_info.refers = ref_paths

    My_info.output = output_path

    My_info.config = "voicefilter/config/config.yaml"
    My_info.embedded = "voicefilter/embedder.pt"
    My_info.chkpt = "D:/chkpt/my_model0330_2/chkpt_140000.pt"

    #main(My_info) # 단일

    My_info.num = sn
    # My_info.refers = ["voicefilter/ref1.wav", "voicefilter/ref2.wav"]
    main_multi(My_info) # 멀티

    # ------------------------ stt
    from stt.stt_func import convert_to_mono_wav,transcribe_file, enhanced_file, stt_speech

    language = "ko-KR" if lang == '한국어' else "en-US"
    stt_result = []

    for filename in os.listdir(output_path):
        # 파일 경로 생성
        file_path = os.path.join(output_path, filename)
        # 파일이 실제 파일인지 확인
        if os.path.isfile(file_path):
            convert_to_mono_wav(file_path)
            enhanced_output_path = enhanced_file(file_path)
            # Firebase에 올리기
            stt_result.append(stt_speech(enhanced_output_path, language))
    return stt_result