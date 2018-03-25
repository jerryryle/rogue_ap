from flask import escape, Flask, g, jsonify, render_template, request

app = Flask(__name__, static_folder='static', template_folder='templates')
app.config.from_object(__name__)


@app.route("/")
def index():
    return render_template('index.html')


@app.route("/generate_204")
def generate_204():
    return '', 204


if __name__ == '__main__':
    app.config.update(dict(SECRET_KEY='test'))
    app.run(debug=True)
