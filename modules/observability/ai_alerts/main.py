import base64
import json
import os
from flask import Flask, request, jsonify
import google.cloud.aiplatform as aiplatform
import requests

PROJECT_ID = "ardent-disk-474504-c0"
LOCATION = "us-central1"
CHAT_WEBHOOK_URL = "https://chat.googleapis.com/v1/spaces/AAQAGKxqmro/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=3GAX29aYu5cZ_CAhSq3EOxRke1jgBHGEGg2iSgtSbmc"
MODEL_NAME = os.environ.get("MODEL_NAME", "gemini-1.5-pro")

app = Flask(__name__)

def init_vertex():
    aiplatform.init(project=PROJECT_ID, location=LOCATION)

def analyze_log(log_entry):
    """Call Vertex AI to summarize + suggest fix."""
    init_vertex()
    from vertexai.generative_models import GenerativeModel

    model = GenerativeModel(MODEL_NAME)

    prompt = f"""
You are a senior SRE / system admin.

You receive this GCP log entry (JSON):

{json.dumps(log_entry, indent=2)}

Tasks:
1. Short title (max 80 chars)
2. Summary (1–3 sentences)
3. Probable root cause (max 3 bullet points)
4. Recommended actions (max 5 bullet points)

Return answer in this JSON format:
{{
  "title": "...",
  "summary": "...",
  "root_cause": ["..."],
  "actions": ["..."]
}}
"""

    resp = model.generate_content(prompt)
    text = resp.candidates[0].content.parts[0].text

    # Try to parse JSON; if fail, wrap as text
    try:
        data = json.loads(text)
    except Exception:
        data = {"title": "AI log analysis", "summary": text,
                "root_cause": [], "actions": []}
    return data

def send_to_chat(ai_result, raw_log):
    title = ai_result.get("title", "AI Log Alert")
    summary = ai_result.get("summary", "")
    root_cause = ai_result.get("root_cause", [])
    actions = ai_result.get("actions", [])

    rc_text = "\n".join(f"- {r}" for r in root_cause) or "- (not sure)"
    act_text = "\n".join(f"- {a}" for a in actions) or "- (no specific action)"

    log_snippet = json.dumps(raw_log, indent=2)[:1500]

    text = f"""🔥 *{title}*

*Summary*  
{summary}

*Probable root cause*  
{rc_text}

*Recommended actions*  
{act_text}

*Raw log (truncated)*  
```json
{log_snippet}
```"""

    requests.post(CHAT_WEBHOOK_URL, json={"text": text})

@app.route("/", methods=["POST"])
def handle_pubsub():
    envelope = request.get_json()
    if not envelope or "message" not in envelope:
        return ("No message", 400)

    msg = envelope["message"]
    data = msg.get("data")

    if data:
        payload = base64.b64decode(data).decode("utf-8")
        try:
            log_entry = json.loads(payload)
        except Exception:
            log_entry = {"textPayload": payload}
    else:
        log_entry = {}

    ai_result = analyze_log(log_entry)
    send_to_chat(ai_result, log_entry)

    return jsonify(status="ok")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
