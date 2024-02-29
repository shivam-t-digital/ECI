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
    username = request.json.get('username', None)
    password = request.json.get('password', None)
    # Check if username and password match with the ones from the .env file
    if username != Config.USERNAME or password != Config.PASSWORD:
        return jsonify({"msg": "Bad username or password"}), 401

    # Create access token
    access_token = create_access_token(identity=username)
    # Get the expiration time of the token
    expires = datetime.utcnow() + app.config['JWT_ACCESS_TOKEN_EXPIRES']

    # Calculate remaining validity time in minutes
    validity_minutes = int((expires - datetime.utcnow()).total_seconds() / 60)

    return jsonify(access_token=access_token, expires_in_minutes=validity_minutes),200


@users_bp.route('/user_details', methods=['POST'])
def save_user_details():
    try:
        data = request.json
        user_ip, name, email, phn_no, address, dob, image_base64 = (
            data.get('user_ip'),
            data.get('name'),
            data.get('email'),
            data.get('phn_no'),
            data.get('address'),
            data.get('dob'),
            data.get('image')
        )
        image_bytes = None
        if image_base64 is not None:
            padded_base64 = image_base64 + '=' * (-len(image_base64) % 4)
            image_bytes = base64.b64decode(padded_base64)

        existing_user = UserDetails.query.filter_by(email=email).first()
        if existing_user:
            existing_user.cert += 1
        else:
            user_details = UserDetails(
                user_ip=user_ip,
                name=name,
                email=email,
                phn_no=phn_no,
                address=address,
                dob=dob,
                image=image_bytes,
                cert=1
            )
            db.session.add(user_details)

        db.session.commit()
        return jsonify({'message': 'User details saved successfully'}), 200

    except Exception as e:
        db.session.rollback()
        print('Error:', e)
        return jsonify({'error': 'An error occurred while saving user details'}), 500

@users_bp.route('/geo_details', methods=['POST'])
# @jwt_required()
def save_geo_details():
    try:
        data = request.json
        user_ip, device_data = data.get('user_ip'), data.get('device_data')
        ip_details = get_ip_details(user_ip)
        geo_details = UserGeographicDetails(
            user_ip=user_ip,
            device_data_json=json.dumps(device_data),
            user_geo_details=ip_details
        )
        db.session.add(geo_details)
        db.session.commit()
        return jsonify({'message': 'User geographic details saved successfully', 'data': data}), 200

    except Exception as e:
        db.session.rollback()
        print('Error:', e)
        return jsonify({'error': 'An error occurred while saving geographic details'}), 500



def get_ip_details(ip_address):
    try:
        # Make a request to the BigDataCloud API to get IP details
        response = requests.get(f'https://api.bigdatacloud.net/data/reverse-geocode-client?ip={ip_address}')

        # Check if the request was successful
        if response.status_code == 200:
            # Extract IP details from the response
            ip_details = response.json()
            return json.dumps(ip_details)
        else:
            # Return an error message if the request failed
            return jsonify({
                'error': 'Failed to fetch IP details from the third-party API'
            }), 500
    except Exception as e:
        # Return an error message
        return jsonify({
            'error': 'An unexpected error occurred while processing the request'
        }), 500
    

@users_bp.route('/quiz_data', methods=['GET'])
# @jwt_required()
def get_quiz_data():
    section = request.args.get('section')

    # Validate section
    if section not in ['A', 'B', 'C']:
        return jsonify({'error': 'Invalid section'})

    quiz_data = []

    # Query the database to get questions for the specified section
    questions = Question.query.filter_by(section=section).all()
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
    return jsonify(quiz_data)



@users_bp.route('/image/<int:image_id>', methods=['GET'])
def get_image(image_id):
    try:
        image_data = UI_elements.query.get(image_id)
        if image_data and image_data.image:
            image_path = image_data.image
            if os.path.exists(image_path):
                _, extension = os.path.splitext(image_path)
                mimetype = {
                    '.jpg': 'image/jpeg',
                    '.png': 'image/png',
                    '.gif': 'image/gif'
                }.get(extension.lower(), 'application/octet-stream')

                with open(image_path, 'rb') as f:
                    image_bytes = f.read()

                return send_file(io.BytesIO(image_bytes), mimetype=mimetype), 200
            else:
                return 'Image file not found', 404
        else:
            return 'Image not found', 404

    except Exception as e:
        print('Error:', e)
        return 'An error occurred while processing the request', 500