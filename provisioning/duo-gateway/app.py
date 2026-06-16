#!/usr/bin/env python3
"""
Duo MFA gateway for EVE-NG.

Sits in front of EVE-NG (behind nginx). Presents one branded black/orange
login page that:
  1. Verifies username/password against EVE-NG's own auth API
     (so we don't maintain a second user store).
  2. Runs the Duo Universal Prompt as the second factor.
  3. On success, sets a signed gateway session cookie *and* re-issues the
     EVE 'unetlab_session' cookie so the user lands straight in EVE with no
     second login.

nginx calls GET /gw/auth as an auth_request subrequest: 200 = allow, 401 = deny.
"""
import os
import time

import requests
from flask import (Flask, request, redirect, render_template, make_response,
                   abort)
from itsdangerous import URLSafeTimedSerializer, BadSignature, SignatureExpired
from duo_universal.client import Client, DuoException

# ---------------------------------------------------------------------------
# Config (all from environment; see gateway.env.example)
# ---------------------------------------------------------------------------
SECRET_KEY        = os.environ["GATEWAY_SECRET_KEY"]
DUO_CLIENT_ID     = os.environ["DUO_CLIENT_ID"]
DUO_CLIENT_SECRET = os.environ["DUO_CLIENT_SECRET"]
DUO_API_HOST      = os.environ["DUO_API_HOST"]
SERVER_NAME       = os.environ["SERVER_NAME"]                       # lab.radiobelcher.com
EVE_UPSTREAM      = os.environ.get("EVE_UPSTREAM", "http://127.0.0.1:80")
SESSION_TTL       = int(os.environ.get("SESSION_TTL", "28800"))     # 8h
PENDING_TTL       = 300                                             # 5 min for the Duo round-trip
REDIRECT_URI      = f"https://{SERVER_NAME}/gw/duo-callback"

app = Flask(__name__)
session_signer = URLSafeTimedSerializer(SECRET_KEY, salt="gw-session")
pending_signer = URLSafeTimedSerializer(SECRET_KEY, salt="gw-pending")

duo_client = Client(
    client_id=DUO_CLIENT_ID,
    client_secret=DUO_CLIENT_SECRET,
    host=DUO_API_HOST,
    redirect_uri=REDIRECT_URI,
)

COOKIE_KW = dict(secure=True, httponly=True, samesite="Lax", path="/")


def _safe_redirect(target: str) -> str:
    """Only allow same-host relative redirects to avoid open-redirect."""
    if target and target.startswith("/") and not target.startswith("//"):
        return target
    return "/"


def _eve_login(username: str, password: str):
    """Return the EVE unetlab_session cookie value on success, else None."""
    try:
        s = requests.Session()
        r = s.post(f"{EVE_UPSTREAM}/api/auth/login",
                   json={"username": username, "password": password, "html5": "-1"},
                   timeout=10)
        if r.status_code == 200 and r.json().get("status") == "success":
            return s.cookies.get("unetlab_session")
    except (requests.RequestException, ValueError):
        pass
    return None


# ---------------------------------------------------------------------------
# nginx auth_request target
# ---------------------------------------------------------------------------
@app.route("/gw/auth")
def auth():
    token = request.cookies.get("gw_session")
    if not token:
        return ("", 401)
    try:
        session_signer.loads(token, max_age=SESSION_TTL)
        return ("", 200)
    except (BadSignature, SignatureExpired):
        return ("", 401)


# ---------------------------------------------------------------------------
# Login page (factor 1) -> kicks off Duo (factor 2)
# ---------------------------------------------------------------------------
@app.route("/gw/login", methods=["GET", "POST"])
def login():
    rd = _safe_redirect(request.args.get("rd", "/"))
    if request.method == "GET":
        return render_template("login.html", error=None, rd=rd)

    username = request.form.get("username", "").strip()
    password = request.form.get("password", "")
    eve_session = _eve_login(username, password)
    if not eve_session:
        return render_template("login.html",
                               error="Invalid username or password.", rd=rd), 401

    try:
        duo_client.health_check()
    except DuoException:
        return render_template("login.html",
                               error="Duo service unavailable. Try again shortly.",
                               rd=rd), 503

    state = duo_client.generate_state()
    prompt_uri = duo_client.create_auth_url(username, state)

    pending = pending_signer.dumps(
        {"state": state, "username": username, "eve": eve_session, "rd": rd})
    resp = make_response(redirect(prompt_uri, code=302))
    resp.set_cookie("gw_pending", pending, max_age=PENDING_TTL, **COOKIE_KW)
    return resp


# ---------------------------------------------------------------------------
# Duo callback -> establish session
# ---------------------------------------------------------------------------
@app.route("/gw/duo-callback")
def duo_callback():
    code = request.args.get("duo_code")
    state = request.args.get("state")
    raw = request.cookies.get("gw_pending")
    if not (code and state and raw):
        abort(400)

    try:
        pending = pending_signer.loads(raw, max_age=PENDING_TTL)
    except (BadSignature, SignatureExpired):
        return redirect("/gw/login")

    if state != pending["state"]:
        abort(400, "state mismatch")

    try:
        duo_client.exchange_authorization_code_for_2fa_result(code, pending["username"])
    except DuoException:
        return render_template("login.html",
                               error="Two-factor authentication failed.",
                               rd=pending["rd"]), 401

    session = session_signer.dumps({"u": pending["username"], "t": int(time.time())})
    resp = make_response(redirect(_safe_redirect(pending["rd"]), code=302))
    resp.set_cookie("gw_session", session, max_age=SESSION_TTL, **COOKIE_KW)
    # Hand the EVE session cookie back to the browser so EVE sees them as logged in.
    resp.set_cookie("unetlab_session", pending["eve"], **COOKIE_KW)
    resp.delete_cookie("gw_pending", path="/")
    return resp


@app.route("/gw/logout")
def logout():
    resp = make_response(redirect("/gw/login"))
    resp.delete_cookie("gw_session", path="/")
    resp.delete_cookie("unetlab_session", path="/")
    return resp


@app.route("/gw/healthz")
def healthz():
    return ("ok", 200)


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
