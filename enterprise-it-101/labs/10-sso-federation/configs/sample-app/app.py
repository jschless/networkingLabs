"""
Tiny OIDC-protected web app for Enterprise IT 101 Lab 10 (GIVEN scaffolding).

It does the smallest interesting thing: protect a single page behind Keycloak
using the OIDC Authorization-Code flow, then show the logged-in user's identity
and the *decoded claims* from their token — including the AD group memberships
that Keycloak mapped in. You configure the OIDC client in Keycloak; this app just
consumes it via three environment variables.

  OIDC_DISCOVERY_URL  e.g. http://keycloak.lab.corp:8080/realms/lab-corp/.well-known/openid-configuration
  OIDC_CLIENT_ID      the client you create in Keycloak (e.g. sample-app)
  OIDC_CLIENT_SECRET  the secret Keycloak generates for that client

The app trusts ONE canonical name for Keycloak (keycloak.lab.corp:8080) for both
the browser redirect and its own server-side token call — see the README setup
step that maps that name on your host.
"""
import os

from authlib.integrations.flask_client import OAuth
from flask import Flask, redirect, render_template_string, session, url_for

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET", "lab-corp-dev-secret")

oauth = OAuth(app)
oauth.register(
    name="keycloak",
    server_metadata_url=os.environ["OIDC_DISCOVERY_URL"],
    client_id=os.environ["OIDC_CLIENT_ID"],
    client_secret=os.environ["OIDC_CLIENT_SECRET"],
    client_kwargs={"scope": "openid profile email"},
)

PAGE = """
<!doctype html>
<title>Lab Corp — Sample App</title>
<body style="font-family: system-ui, sans-serif; max-width: 48rem; margin: 3rem auto;">
  <h1>Lab Corp — Sample App</h1>
  {% if user %}
    <p>You are signed in via <strong>Keycloak SSO</strong> as
       <strong>{{ user.get('preferred_username', user.get('sub')) }}</strong>.</p>
    <p>You never gave this app a password — Keycloak (brokering Active Directory)
       vouched for you with the token below.</p>
    <h2>Decoded ID-token claims</h2>
    <pre style="background:#f4f4f4; padding:1rem; overflow:auto;">{{ claims }}</pre>
    <p><a href="{{ url_for('logout') }}">Log out</a></p>
  {% else %}
    <p>You are not signed in.</p>
    <p><a href="{{ url_for('login') }}">Sign in with Keycloak</a></p>
  {% endif %}
</body>
"""


@app.route("/")
def index():
    user = session.get("user")
    claims = ""
    if user:
        import json

        claims = json.dumps(user, indent=2, sort_keys=True)
    return render_template_string(PAGE, user=user, claims=claims)


@app.route("/login")
def login():
    return oauth.keycloak.authorize_redirect(
        url_for("callback", _external=True)
    )


@app.route("/callback")
def callback():
    token = oauth.keycloak.authorize_access_token()
    # userinfo / id_token claims (preferred_username, email, groups, ...)
    session["user"] = token.get("userinfo") or {}
    return redirect(url_for("index"))


@app.route("/logout")
def logout():
    session.pop("user", None)
    return redirect(url_for("index"))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("APP_PORT", "5000")))
