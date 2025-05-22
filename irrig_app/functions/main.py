# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

import firebase_admin
from firebase_admin import credentials, auth
from flask import jsonify, Request


cred = credentials.Certificate("scmu-6f1b8-firebase-adminsdk-fbsvc-bc6b3767d5.json")
firebase_admin.initialize_app(cred)

def generate_token(request: Request):
    request_json = request.get_json(silent=True)
    request_args = request.args

    uid = None
    if request_json and 'uid' in request_json:
        uid = request_json['uid']
    elif request_args and 'uid' in request_args:
        uid = request_args['uid']

    if not uid:
        return jsonify({"error": "Missing 'uid' in request"}), 400

    try:
        # Generate a custom token for the provided UID
        custom_token = auth.create_custom_token(uid)
        return jsonify({
            "token": custom_token.decode('utf-8')
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500
