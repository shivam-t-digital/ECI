from decouple import config

# # For local
class Config:
  SQLALCHEMY_DATABASE_URI = config("DB_CONN_STRING")
  # SQLALCHEMY_DATABASE_URI = 'mysql://root:root@localhost:3306/eci'
  SQLALCHEMY_TRACK_MODIFICATIONS = False 
  JWT_SECRET_KEY = config("JWT_SECRET_KEY")  # Change this!
  USERNAME = config("USERNAME_1")
  PASSWORD = config("PASSWORD")
  
