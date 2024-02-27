from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import ForeignKey, DateTime, func
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship

# Create an instance of SQLAlchemy
db = SQLAlchemy()


# Define the Question model
class Question(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    question_text = db.Column(db.String(255), nullable=False)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    section = db.Column(db.String(1), nullable=False)
    answers = db.relationship('Answer', backref='question', uselist=True)


# Define the Answer model
class Answer(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    answer_text = db.Column(db.String(255), nullable=False)
    question_id = db.Column(db.Integer, db.ForeignKey('question.id'), nullable=False)
    correct_explanation = db.relationship('CorrectExplanation', backref='answer', uselist=False)
    correct = db.Column(db.Boolean, default=False) 


# Define the CorrectExplanation model
class CorrectExplanation(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    explanation_text = db.Column(db.String(255), nullable=False)
    answer_id = db.Column(db.Integer, db.ForeignKey('answer.id'), nullable=False)


# Define the UserGeographicDetails model
class UserGeographicDetails(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_ip = db.Column(db.String(45), nullable=False)
    device_data_json = db.Column(db.Text, nullable=False)
    user_geo_details = db.Column(db.Text, nullable=True)


# Define the UserDetails model
class UserDetails(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_ip = db.Column(db.String(45), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    address = db.Column(db.String(250), nullable=False)
    email = db.Column(db.String(100), nullable=False)
    dob = db.Column(db.String(20), nullable=False)
    image = db.Column(db.LargeBinary, nullable=True)
    cert = db.Column(db.Integer, default=0)
    phn_no = db.Column(db.String(15), nullable=True)


# Define the UserProgress model
class UserProgress(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    question_id = db.Column(db.Integer, db.ForeignKey('question.id'), nullable=False)
    answer_id = db.Column(db.Integer, db.ForeignKey('answer.id'), nullable=False)
    is_correct = db.Column(db.Boolean, default=False)

    # Define relationship with Question and Answer models
    question = db.relationship('Question', backref='user_progress')
    answer = db.relationship('Answer', backref='user_progress')


# Define the UI_elements model
class UI_elements(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    round = db.Column(db.Integer, nullable=False)
    image = db.Column(db.LargeBinary, nullable=True)
    description = db.Column(db.Text, nullable=True)
    placement = db.Column(db.String(50))  



