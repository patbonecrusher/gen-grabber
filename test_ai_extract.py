#!/usr/bin/env python3
"""Test AI record extraction against LaFrance images."""

import base64, json, sys, urllib.request, glob, os, time

BASE_URL = "https://api.openai.com/v1"
MODEL = "gpt-4o-mini"
TOKEN = os.environ.get("OPENAI_API_KEY", "")

PROMPT = (
    'Look at this genealogy record screenshot carefully. Extract ALL visible information into structured JSON. '
    'Return a JSON object with these fields: '
    '"recordType" (one of "Marriage", "Baptism", "Burial"), '
    '"date" (the date of the event, e.g. "21-Jan-1808"), '
    '"parish" (the parish name), '
    '"region" (the region/location), '
    '"documentFilename" (the original document filename if visible, e.g. "d1p_1234567"), '
    '"persons" (an array of person objects). '
    'Each person object should have: '
    '"name" (format "LASTNAME, Firstname"), '
    '"role" (e.g. "Subject", "Father of groom", "Mother of groom", "Father of bride", "Mother of bride", "Groom", "Bride", "Witness"), '
    '"maritalStatus" (e.g. "Single", "Married", "Widowed", or empty), '
    '"sex" (e.g. "M", "F", or empty), '
    '"age" (e.g. "25" or empty), '
    '"occupation" (or empty). '
    'Extract every person mentioned in the record. Return ONLY the JSON object, no other text.'
)

def extract_json(text):
    text = text.strip()
    if text.startswith("```json"):
        text = text[7:]
    elif text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    text = text.strip()
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end != -1:
        return text[start:end+1]
    return text

def test_image(path):
    print(f"\n{'='*60}")
    print(f"Testing: {os.path.basename(path)}")
    print(f"{'='*60}")

    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()

    body = json.dumps({
        "model": MODEL,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "text", "text": PROMPT},
                {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}},
            ],
        }],
        "max_tokens": 2000,
    }).encode()

    headers = {"Content-Type": "application/json"}
    if TOKEN:
        headers["Authorization"] = f"Bearer {TOKEN}"

    req = urllib.request.Request(
        f"{BASE_URL}/chat/completions",
        data=body,
        headers=headers,
    )

    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                data = json.loads(resp.read())
            break
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 2:
                wait = 30 * (attempt + 1)
                print(f"Rate limited, waiting {wait}s...")
                time.sleep(wait)
                continue
            print(f"REQUEST FAILED: HTTP {e.code}: {e.read().decode()}")
            return
        except Exception as e:
            print(f"REQUEST FAILED: {e}")
            return

    content = data["choices"][0]["message"]["content"]
    print(f"\nRaw AI response:\n{content}\n")

    json_str = extract_json(content)
    try:
        parsed = json.loads(json_str)
        print(f"Parsed JSON (pretty):")
        print(json.dumps(parsed, indent=2, ensure_ascii=False))

        # Check types
        for key, val in parsed.items():
            if key == "persons":
                for i, p in enumerate(val):
                    for pk, pv in p.items():
                        if not isinstance(pv, str):
                            print(f"  WARNING: persons[{i}].{pk} is {type(pv).__name__}: {pv}")
            elif not isinstance(val, (str, list)):
                print(f"  WARNING: {key} is {type(val).__name__}: {val}")
    except json.JSONDecodeError as e:
        print(f"JSON PARSE FAILED: {e}")
        print(f"Extracted JSON string: {json_str}")

if __name__ == "__main__":
    folder = sys.argv[1] if len(sys.argv) > 1 else "."
    images = sorted(glob.glob(os.path.join(folder, "*-lafrance.png")))
    if not images:
        print(f"No *-lafrance.png files found in {folder}")
        sys.exit(1)
    print(f"Found {len(images)} LaFrance images")
    for i, img in enumerate(images):
        test_image(img)
        if i < len(images) - 1:
            print("\nWaiting 5s before next image...")
            time.sleep(5)
