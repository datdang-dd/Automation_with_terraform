import base64
import json
import os
import re
from typing import Any, Dict

from flask import Flask, request, jsonify
import requests

# ✅ SDK mới dành cho Gemini 2.5
from google import genai
from google.genai import types

# --- CẤU HÌNH ---
PROJECT_ID = os.environ.get("PROJECT_ID", "ardent-disk-474504-c0")
LOCATION = os.environ.get("LOCATION", "us-central1")

# ⚠️ Điền webhook URL bằng secret / env in production
CHAT_WEBHOOK_URL = os.environ.get(
    "CHAT_WEBHOOK_URL",
    "https://chat.googleapis.com/v1/spaces/AAQAGKxqmro/messages?key=YOUR_KEY&token=YOUR_TOKEN",
)

# ✅ Sử dụng model Gemini 2.5 Flash
MODEL_NAME = os.environ.get("MODEL_NAME", "gemini-2.5-flash")

app = Flask(__name__)


def get_genai_client() -> genai.Client:
    """Khởi tạo Client Vertex AI với SDK google-genai mới."""
    return genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)


def clean_json_response(text: str) -> str:
    """Strip common markdown fences so json.loads doesn't fail.

    Gemini models sometimes wrap JSON in ```json ... ``` blocks.
    """
    cleaned = re.sub(r"^```json\s*", "", text.strip(), flags=re.IGNORECASE | re.MULTILINE)
    cleaned = re.sub(r"^```\s*", "", cleaned, flags=re.MULTILINE)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    return cleaned.strip()


def analyze_log(log_entry: Dict[str, Any]) -> Dict[str, Any]:
    """Send the log entry to Gemini and parse the returned JSON analysis.

    Returns a dict with keys: title, summary, root_cause (list), actions (list).
    """
    client = get_genai_client()
    log_str = json.dumps(log_entry, indent=2)

    prompt = (
        "You are a senior SRE / System Admin.\n"
        "Analyze this GCP log entry:\n\n"
        f"{log_str}\n\n"
        "Output ONLY a raw JSON object (no markdown formatting) with these fields:\n"
        "- title: Short title (max 80 chars).\n"
        "- summary: 1-2 sentences explaining what happened.\n"
        "- root_cause: List of probable causes (strings).\n"
        "- actions: List of recommended fix commands or actions (strings).\n"
    )

    try:
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=prompt,
            config=types.GenerateContentConfig(response_mime_type="application/json"),
        )

        # response may expose text or content; try to be flexible
        text = getattr(response, "text", None)
        if text is None:
            # fallback: try str(response) or content
            text = getattr(response, "content", None) or str(response)

        data = json.loads(clean_json_response(str(text)))

    except Exception as e:  # pylint: disable=broad-except
        print(f"Gemini Analysis Error: {e}")
        data = {
            "title": "AI Analysis Failed",
            "summary": f"Error calling Gemini: {str(e)}",
            "root_cause": ["Check Cloud Run logs for details"],
            "actions": ["Manual investigation required"],
        }

    return data


def send_to_chat(ai_result: Dict[str, Any], raw_log: Dict[str, Any]) -> None:
    """Send the AI analysis to Google Chat via webhook.

    The message is a simple plain-text payload. In production, consider using
    a secret manager to store the webhook URL and signing/verifying messages.
    """
    title = ai_result.get("title", "GCP Log Alert")
    summary = ai_result.get("summary", "No summary provided.")

    rc_list = ai_result.get("root_cause") or []
    act_list = ai_result.get("actions") or []

    rc_text = "\n".join(f"• {r}" for r in rc_list) if rc_list else "_Analyzing..._"
    act_text = "\n".join(f"• {a}" for a in act_list) if act_list else "_No specific action._"

    log_snippet = json.dumps(raw_log, indent=2)
    if len(log_snippet) > 1000:
        log_snippet = log_snippet[:1000] + "\n... (truncated)"

    msg_text = (
        f"🔥 {title}\n\n"
        f"Summary:\n{summary}\n\n"
        f"Probable Root Cause:\n{rc_text}\n\n"
        f"Recommended Actions:\n{act_text}\n\n"
        f"Raw Log Snippet:\n{log_snippet}"
    )

    try:
        r = requests.post(CHAT_WEBHOOK_URL, json={"text": msg_text})
        print(f"Chat Webhook Status: {r.status_code}")
        if r.status_code >= 400:
            print(f"Chat Webhook Response: {r.text}")
    except Exception as e:  # pylint: disable=broad-except
        print(f"Failed to send chat message: {e}")


@app.route("/", methods=["POST"])
def handle_pubsub() -> Any:
    """Main entrypoint to receive Pub/Sub push (via Eventarc or direct push).

    Expects the Pub/Sub envelope format with a base64-encoded `message.data`.
    """
    envelope = request.get_json()
    if not envelope:
        return "Bad Request: No JSON", 400

    # Health check or direct test without `message` key
    if "message" not in envelope:
        return "OK", 200

    msg = envelope["message"]
    data = msg.get("data")

    if not data:
        return jsonify(status="no-data")

    try:
        payload = base64.b64decode(data).decode("utf-8")
        log_entry = json.loads(payload)

        print(f"Processing Log ID: {log_entry.get('insertId', 'unknown')}")

        ai_result = analyze_log(log_entry)
        send_to_chat(ai_result, log_entry)

    except Exception as e:  # pylint: disable=broad-except
        print(f"Processing Error: {e}")
        return "Error processing message", 500

    return jsonify(status="ok")


if __name__ == "__main__":
    # Cloud Run injects PORT; default to 8080 for local runs
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)