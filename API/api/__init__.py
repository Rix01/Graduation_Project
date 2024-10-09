from flask import Flask
import firebase_admin
from firebase_admin import credentials, initialize_app

# cred = credentials.Certificate("api/key.json")
# default_app = initialize_app(cred)

def create_app():
    app = Flask(__name__)
    app.config['SECRET_KEY'] = '1234rtfescdvf'
    
    # Firebase 인증 초기화 (처음만 인증. 이후엔 인증 X)
    cred = credentials.Certificate('api/key.json')
    firebase_admin.initialize_app(cred, {
        'projectId': 'example-6daae',
        'storageBucket' : 'example-6daae.appspot.com'
    })
    
    from .userAPI import userAPI
    
    app.register_blueprint(userAPI, url_prefix='/audio_data')
    
    return app