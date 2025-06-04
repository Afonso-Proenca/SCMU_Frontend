import firebase_admin
from firebase_admin import auth, credentials

cred = credentials.Certificate("scmu-6f1b8-firebase-adminsdk-fbsvc-bc6b3767d5.json")
firebase_admin.initialize_app(cred)

uid = "atu1PPJnirW3mKWdx1mx3uxvWTF3"
user = auth.get_user(uid)
print(user.custom_claims)