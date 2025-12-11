import base64
import json
import os
import re
from typing import Any, Dict, Optional

from flask import Flask, request, jsonify
import requests

app = Flask(__name__)

# --- CONFIG ---

PROJECT_ID = os.environ.get("PROJECT_ID", "ardent-disk-474504-c0")

# Webhook Google Chat – NÊN set qua env/secret trên Cloud Run
CHAT_WEBHOOK_URL = os.environ.get(
    "CHAT_WEBHOOK_URL",
    "https://chat.googleapis.com/v1/spaces/AAQAGKxqmro/messages?key=YOUR_KEY&token=YOUR_TOKEN",
)


# --- HELPER PARSE FUNCTIONS ---


def parse_vm_creation(log_entry: Dict[str, Any]) -> Dict[str, Optional[str]]:
    """
    Parse info when a new Compute Engine VM is created.

    Log pattern:
      protoPayload.methodName = "v1.compute.instances.insert"
      protoPayload.resourceName = "projects/PROJECT/zones/ZONE/instances/INSTANCE_NAME"
    """
    proto = log_entry.get("protoPayload", {})
    resource_name = proto.get("resourceName", "")  # full resource path

    project = None
    zone = None
    instance = None

    # Try parse from resourceName
    # Example: projects/ardent-disk-474504-c0/zones/us-central1-b/instances/test-vm
    m = re.match(
        r"projects/(?P<project>[^/]+)/zones/(?P<zone>[^/]+)/instances/(?P<instance>[^/]+)",
        resource_name,
    )
    if m:
        project = m.group("project")
        zone = m.group("zone")
        instance = m.group("instance")

    # Fallback project from log resource
    if not project:
        project = (
            log_entry.get("resource", {})
            .get("labels", {})
            .get("project_id", PROJECT_ID)
        )

    # Fallback zone from log resource
    if not zone:
        zone = log_entry.get("resource", {}).get("labels", {}).get("zone")

    return {
        "project": project,
        "zone": zone,
        "instance": instance,
        "resource_name": resource_name or None,
    }


def parse_service_enable(log_entry: Dict[str, Any]) -> Dict[str, Optional[str]]:
    """
    Parse info when an API/service is enabled.

    Common fields:
      protoPayload.methodName:
        - "google.api.servicemanagement.v1.ServiceManager.EnableService"
        - "google.api.serviceusage.v1.ServiceUsage.EnableService"

      protoPayload.request.serviceName: "compute.googleapis.com"
      protoPayload.resourceName: "projects/123456/services/compute.googleapis.com"
    """
    proto = log_entry.get("protoPayload", {})
    request_obj = proto.get("request", {}) or {}

    service_name = request_obj.get("serviceName")  # full service name
    resource_name = proto.get("resourceName", "")

    # Try to extract project from resourceName: projects/123456/services/xxx
    project = None
    m = re.match(r"projects/(?P<project>[^/]+)/services/(?P<service>[^/]+)", resource_name)
    if m:
        project = m.group("project")
        if not service_name:
            service_name = m.group("service")

    if not project:
        project = (
            log_entry.get("resource", {})
            .get("labels", {})
            .get("project_id", PROJECT_ID)
        )

    return {
        "project": project,
        "service_name": service_name,
        "resource_name": resource_name or None,
    }


def send_to_chat(text: str) -> None:
    """Send plain-text message to Google Chat via incoming webhook."""
    if not CHAT_WEBHOOK_URL:
        print("CHAT_WEBHOOK_URL is not set, skip sending message.")
        return

    try:
        resp = requests.post(CHAT_WEBHOOK_URL, json={"text": text})
        print(f"Chat Webhook Status: {resp.status_code}")
        if resp.status_code >= 400:
            print(f"Chat Webhook Response: {resp.text}")
    except Exception as e:  # noqa: BLE001
        print(f"Failed to send chat message: {e}")


# --- MAIN HANDLER ---


@app.route("/", methods=["POST"])
def handle_pubsub() -> Any:
    """
    Main entrypoint for Pub/Sub push (via Logging sink → Pub/Sub → push).

    Expected envelope:
    {
      "message": {
        "data": "<base64-encoded-log-entry>",
        ...
      },
      "subscription": "projects/.../subscriptions/..."
    }
    """
    envelope = request.get_json()
    if not envelope:
        return "Bad Request: No JSON body", 400

    # Health check or direct ping
    if "message" not in envelope:
        return "OK", 200

    msg = envelope["message"]
    data = msg.get("data")
    if not data:
        return jsonify(status="no-data")

    try:
        payload = base64.b64decode(data).decode("utf-8")
        log_entry = json.loads(payload)
    except Exception as e:  # noqa: BLE001
        print(f"Failed to decode Pub/Sub message: {e}")
        return "Invalid message", 400

    # --- COMMON FIELDS ---
    proto = log_entry.get("protoPayload", {})
    method = proto.get("methodName", "unknown_method")
    principal = (
        proto.get("authenticationInfo", {}).get("principalEmail", "unknown_principal")
    )
    timestamp = log_entry.get("timestamp", "unknown_time")

    # Default values
    title = "GCP Audit Event"
    details_lines = []
    event_type = "generic"

    # --- DETECT TYPE: VM CREATED ---
    if method == "v1.compute.instances.insert":
        event_type = "vm_created"
        vm_info = parse_vm_creation(log_entry)
        title = "🚀 New VM Created"

        details_lines.append(f"- Project: `{vm_info.get('project')}`")
        details_lines.append(f"- Zone: `{vm_info.get('zone')}`")
        details_lines.append(f"- VM Name: `{vm_info.get('instance')}`")

        if vm_info.get("resource_name"):
            details_lines.append(f"- Resource: `{vm_info['resource_name']}`")

    # --- DETECT TYPE: SERVICE ENABLED ---
    elif method in (
        "google.api.servicemanagement.v1.ServiceManager.EnableService",
        "google.api.serviceusage.v1.ServiceUsage.EnableService",
    ):
        event_type = "service_enabled"
        svc_info = parse_service_enable(log_entry)
        title = "🧩 New API / Service Enabled"

        details_lines.append(f"- Project: `{svc_info.get('project')}`")
        details_lines.append(f"- Service: `{svc_info.get('service_name')}`")

        if svc_info.get("resource_name"):
            details_lines.append(f"- Resource: `{svc_info['resource_name']}`")

    # --- FALLBACK: OTHER EVENT ---
    else:
        title = "ℹ️ GCP Audit Log Event"
        details_lines.append(f"- Method: `{method}`")

    # --- BUILD MESSAGE TEXT ---
    # Raw log snippet (truncated to avoid spam)
    raw_snippet = json.dumps(log_entry, indent=2)
    if len(raw_snippet) > 1500:
        raw_snippet = raw_snippet[:1500] + "\n... (truncated)"

    details_block = "\n".join(details_lines) if details_lines else "- (no extra details)"

    text = (
        f"{title}\n\n"
        f"*Event Type*: `{event_type}`\n"
        f"*Time*: `{timestamp}`\n"
        f"*Actor*: `{principal}`\n\n"
        f"*Details:*\n"
        f"{details_block}\n\n"
        f"*Raw Log:*\n"
        f"```json\n"
        f"{raw_snippet}\n"
        f"```"
    )

    print("Sending alert to Chat...")
    send_to_chat(text)

    return jsonify(status="ok")


if __name__ == "__main__":
    # Cloud Run injects PORT; default to 8080 for local testing
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
