# AI LaFrance Parsing — Design Spec

Add AI-powered parsing of LaFrance screenshots to auto-extract the year and record ID.

## Settings

Stored in `UserDefaults`, persists across sessions. Accessible via a gear icon button in the bottom bar, which opens a settings sheet.

Fields:
- **AI Base URL**: String, e.g. `http://localhost:11434/v1` or `https://api.openai.com/v1`
- **API Token**: String (password field), can be empty for local models
- **Model Name**: String, e.g. `gpt-4o`, `llava`

All three fields are plain text inputs. No validation beyond checking they're non-empty before making a request (token can be empty).

## Parse LaFrance Button

A button labeled "Parse" (or with a wand icon) that appears next to the LaFrance image slot. Only enabled when:
1. A LaFrance image has been pasted
2. AI settings are configured (base URL and model are non-empty)

### Flow

1. User clicks "Parse"
2. Button shows a spinner/progress indicator
3. The app sends the LaFrance image to the AI
4. On success: a confirmation popup shows the extracted Year and Record ID
5. User clicks "Apply" to fill the Year field and the first page's Record ID, or "Cancel" to dismiss
6. On error: an alert shows the error message

### API Call

Uses the OpenAI-compatible `/v1/chat/completions` endpoint with a vision message:

```
POST {baseURL}/chat/completions
Authorization: Bearer {token}
Content-Type: application/json

{
  "model": "{model}",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "Extract the year and the original document filename from this genealogy record screenshot. The date is in the top-right corner (e.g. '21-Jan-1808' — extract just the year: 1808). The original document filename is below the date, something like 'd1p_25401281.jpg' — extract just the ID without the .jpg extension (e.g. d1p_25401281). Respond in JSON only: {\"year\": \"1808\", \"recordID\": \"d1p_25401281\"}"
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/png;base64,{base64image}"
          }
        }
      ]
    }
  ],
  "max_tokens": 100
}
```

The response content is parsed as JSON to extract `year` and `recordID`.

## File Structure

- `GenGrabber/Models/AISettings.swift` — Settings model backed by UserDefaults
- `GenGrabber/Services/AIParserService.swift` — Makes the API call, returns parsed result
- `GenGrabber/Views/SettingsView.swift` — Settings sheet with URL, token, model fields
- `GenGrabber/Views/ImageColumnView.swift` — Modified to add Parse button next to LaFrance slot
