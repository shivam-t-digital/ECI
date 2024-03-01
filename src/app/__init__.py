from flask import Flask
from .config import Config
from .models import db
from .routes import users_bp
from flask_cors import CORS
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager



migrate = Migrate()


def create_app():
    app = Flask(__name__)
    CORS(app, resources={r"*": {"origins": "*", "supports_credentials": True}})
    app.config.from_object(Config)
    db.init_app(app)
    migrate.init_app(app, db)
    jwt = JWTManager(app)
    app.register_blueprint(users_bp)


    with app.app_context():
        db.create_all()
        # migrate = Migrate(app, db)

    # Register a teardown function to close the database connection
    @app.teardown_appcontext
    def teardown_db(exception=None):
        db.session.remove()

    return app
