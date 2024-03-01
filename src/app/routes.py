from flask_sqlalchemy import SQLAlchemy
from flask import Flask, Blueprint, request, jsonify, Response, stream_with_context, send_file
from .models import db, Question, Answer, CorrectExplanation, UserGeographicDetails, UserDetails, UI_elements
from .config import Config
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from werkzeug.security import check_password_hash
from decouple import config
import json
import requests
import base64
from PIL import Image
import io
import os
import logging
from datetime import datetime, timedelta

app = Flask(__name__)
app.config.from_object(Config)
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(minutes=1)
jwt = JWTManager(app)
users_bp = Blueprint('users', __name__)

@users_bp.route('/login', methods=['POST'])
def login():
    print("Login request received")
    username = request.json.get('username', None)
    password = request.json.get('password', None)
    print("username", username)
    print("password", password)
    print("username", Config.USERNAME)
    print("password", Config.PASSWORD)
    # Check if username and password match with the ones from the .env file
    if username != Config.USERNAME or password != Config.PASSWORD:
        return jsonify({"msg": "Bad username or password"}), 401


    # Create access token
    print("Creating access token")
    access_token = create_access_token(identity=username)
    # Get the expiration time of the token
    expires = datetime.utcnow() + app.config['JWT_ACCESS_TOKEN_EXPIRES']

    # Calculate remaining validity time in minutes
    validity_minutes = int((expires - datetime.utcnow()).total_seconds() / 60)

    print("Access token created")
    return jsonify(access_token=access_token, expires_in_minutes=validity_minutes),200


@users_bp.route('/user_details', methods=['POST'])
def save_user_details():
    try:
        # Get data from request JSON
        data = request.json
        print('Received data:', data)
        # Extract user details
        user_ip = data.get('user_ip')
        name = data.get('name')
        email = data.get('email')
        phn_no = data.get('phn_no')
        address = data.get('address')
        dob = data.get('dob')
        image_base64 = data.get('image')
        
        image_bytes = None  # Initialize image_bytes as None
        
        if image_base64 is not None:
            # Ensure proper padding for base64 string
            padded_base64 = image_base64 + '=' * (-len(image_base64) % 4)
            print("Padded base64:", padded_base64)
            
            # Decode base64-encoded image data to bytes
            image_bytes = base64.b64decode(padded_base64)
            print("Decoded image bytes:", image_bytes)

        # Check if the user already exists in the database
        existing_user = UserDetails.query.filter_by(email=email).first()
        if existing_user:
            # If the user exists, increment the cert field by 1
            existing_user.cert += 1
            db.session.commit()
        else:
            # If the user does not exist, save user details to database
            user_details = UserDetails(user_ip=user_ip, name=name, email=email, phn_no=phn_no, address=address, dob=dob, image=image_bytes, cert=1)
            db.session.add(user_details)
            db.session.commit()
            print('User details stored in database:', user_details)

        # Return success response
        return jsonify({'message': 'User details saved successfully'}), 200

    except Exception as e:
        # Log the error
        print('Error:', e)
        # Return error response
        return jsonify({'error': 'An error occurred while saving user details'}), 500

@users_bp.route('/geo_details', methods=['POST'])
# @jwt_required()
def save_geo_details():
    # Get data from request JSON
    data = request.json

    # Extract user IP and device data
    user_ip = data.get('user_ip')
    device_data = data.get('device_data')
    print("Received user IP:", user_ip)
    print("Received device data:", device_data)

    # Get IP details using third-party API
    ip_details=get_ip_details(user_ip)
    print('ip_details:', ip_details)

    # Save IP and device details to database
    geo_details = UserGeographicDetails(user_ip=user_ip, device_data_json=json.dumps(device_data),user_geo_details= ip_details)
    db.session.add(geo_details)
    db.session.commit()

    # Return saved data as JSON response
    return jsonify({
        'message': 'User geographic details saved successfully',
        'data': data
    }), 200



def get_ip_details(ip_address):
    try:
        # Make a request to the BigDataCloud API to get IP details
        response = requests.get(f'https://api.bigdatacloud.net/data/reverse-geocode-client?ip={ip_address}')

        # Check if the request was successful
        if response.status_code == 200:
            # Extract IP details from the response
            ip_details = response.json()
            print("API Response:", ip_details)  # Print API response for troubleshooting

            return json.dumps(ip_details)
        else:
            # Return an error message if the request failed
            return jsonify({
                'error': 'Failed to fetch IP details from the third-party API'
            }), 500
    except Exception as e:
        # Log the exception
        print(f"An error occurred: {e}")

        # Return an error message
        return jsonify({
            'error': 'An unexpected error occurred while processing the request'
        }), 500
    

@users_bp.route('/quiz_data', methods=['GET'])
# @jwt_required()
def get_quiz_data():
    section = request.args.get('section')
    print('Received request for section:', section)

    # Validate section
    if section not in ['A', 'B', 'C']:
        return jsonify({'error': 'Invalid section'})

    quiz_data = []

    # Query the database to get questions for the specified section
    questions = Question.query.filter_by(section=section).all()
    print('Found questions:', questions)

    for idx, question in enumerate(questions, start=1):
        data = {
            'question': question.question_text,
            'options': {},
            'correct': None
        }
        # Fetch all answers for the current question
        answers = Answer.query.filter_by(question_id=question.id).all()
        if not answers:  # Check if there are no answers for the question
            continue

        # Map answers to letters based on the section
        start_ascii = 0
        if section == 'A':
            start_ascii = 97  # ASCII value for 'a'
        elif section == 'B':
            start_ascii = 101  # ASCII value for 'e'
        elif section == 'C':
            start_ascii = 105  # ASCII value for 'i'

        for i, answer in enumerate(answers, start=start_ascii):
            data['options'][chr(i)] = answer.answer_text
            if answer.correct:
                data['correct'] = chr(i)

        quiz_data.append(data)

    print('Returning quiz data:', quiz_data)
    return jsonify(quiz_data)


@users_bp.route('/image/<int:image_id>', methods=['GET'])
def get_image(image_id):
    print(f"Requested image ID: {image_id}")

    # Query the database to retrieve the row containing the image data
    image_data = UI_elements.query.get(image_id)
    print(UI_elements.query.filter_by(id=image_id).statement)
    print("image_data:", image_data)
    
    # Check if image exists
    if image_data and image_data.image:
        print("Image found in the database")

        # Read the image file from the file path
        image_path = image_data.image
        if os.path.exists(image_path):
            with open(image_path, 'rb') as f:
                image_bytes = f.read()

            # Return the image data
            return send_file(io.BytesIO(image_bytes), mimetype='image/jpeg')

        else:
            print("Image file not found:", image_path)
            # Return error message if image file not found
            return 'Image file not found', 404

    else:
        print("Image not found in the database")
        # Return error message if image not found
        return 'Image not found', 404

# @users_bp.route('/image/<int:image_id>', methods=['GET'])
# def get_image(image_id):
#     print(f"Requested image ID: {image_id}")

#     # Query the database to retrieve the row containing the image data
#     image_data = UI_elements.query.get(image_id)
#     print(UI_elements.query.filter_by(id=image_id).statement)
#     print("image_data:", image_data)
    
#     # Check if image exists
#     if image_data and image_data.image:
#         print("Image found in the database")

#         # Read the image file from the file path
#         image_path = image_data.image
#         if os.path.exists(image_path):
#             # Determine the MIME type based on file extension
#             _, extension = os.path.splitext(image_path)
#             if extension.lower() == '.jpg':
#                 mimetype = 'image/jpeg'
#             elif extension.lower() == '.png':
#                 mimetype = 'image/png'
#             elif extension.lower() == '.gif':
#                 mimetype = 'image/gif'
#             else:
#                 # Unsupported file format
#                 return 'Unsupported file format', 415

#             with open(image_path, 'rb') as f:
#                 image_bytes = f.read()

#             # Return the image data
#             return send_file(io.BytesIO(image_bytes), mimetype=mimetype)

#         else:
#             print("Image file not found:", image_path)
#             # Return error message if image file not found
#             return 'Image file not found', 404

#     else:
#         print("Image not found in the database")
#         # Return error message if image not found
#         return 'Image not found', 404