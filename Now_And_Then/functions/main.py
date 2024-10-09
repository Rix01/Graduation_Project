import requests
import firebase_admin
from firebase_admin import initialize_app, firestore, credentials
from firebase_functions import firestore_fn, https_fn
from firebase_functions.firestore_fn import (
  on_document_created,
  Event,
  DocumentSnapshot,
)

# Firebase Admin SDK를 초기화
cred = credentials.ApplicationDefault()
firebase_admin.initialize_app(cred)

# @firestore_fn.on_document_created(document="audio_data/{pushId}") 데코레이터는 
# Firestore의 audio_data 컬렉션에 새로운 문서가 추가될 때마다 new_user 함수를 호출
# new_user 함수는 추가된 데이터의 내용을 가져와서 Flask 앱의 특정 엔드포인트로 전송
@on_document_created(document="audio_data/{pushId}")
def new_audio_data(event: Event[DocumentSnapshot]) -> None:
    if event.data is None:
        return
    try:
        new_value = event.data.to_dict()
        # event.data를 통해 추가된 문서의 데이터에 접근함
        file_name = new_value["fileName"]

    except KeyError:
        # No "original" field, so do nothing.
        return

    # 플라스크 엔드포인트 설정
    flask_endpoint = "https://268c-218-150-182-131.ngrok-free.app/audio_data/triggered"
    
    # 전송할 데이터를 딕셔너리 형태로 만듦
    data = {"fileName": file_name}

    # request.post 함수를 사용하여 Flask 앱의 엔드포인트로 HTTP POST 요청을 보냄
    response = requests.post(flask_endpoint, json=data)

    if response.status_code == 200:
        print("코드 실행 성공!!!")
    else:
        print(f"코드 실행 실패... {response.status_code}")