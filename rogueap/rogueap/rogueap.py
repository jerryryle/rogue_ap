from flask import escape, Flask, g, jsonify, render_template, request

app = Flask(__name__, static_folder='static', static_url_path='/r/static', template_folder='templates')
app.config.from_object(__name__)


@app.route("/", endpoint='index')
@app.route("/r", endpoint='r')
def index():
    return render_template('index.html')


@app.route("/r/204")
def r_204():
    return '', 204


if __name__ == '__main__':
    app.config.update(dict(SECRET_KEY='test'))
    app.run(debug=True)
