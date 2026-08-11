# AI Resume Tailoring & Google Drive Integration Guide

This document provides a comprehensive integration and feature guide for the automated PDF-to-Google Drive resume-tailoring pipeline in the Tatvik AI Coach application.

---

## 🏗 System Architecture

The workflow connects the Flutter PWA frontend, the FastAPI backend, and Google Drive (via OAuth).

```mermaid
sequenceDiagram
    participant User
    participant Flutter PWA
    participant FastAPI Backend
    participant LLM / Gemini API
    participant Google Drive API

    User->>Flutter PWA: Uploads Resume (PDF)
    Flutter PWA->>FastAPI Backend: /resume/upload (PDF binary)
    FastAPI Backend-->>Flutter PWA: Extracted text & ATS scores
    Flutter PWA->>Flutter PWA: Store text & filename in AppState

    User->>Flutter PWA: Submits message/prompts chat
    Flutter PWA->>FastAPI Backend: /mentor/chat (includes resume_context)
    FastAPI Backend->>LLM / Gemini API: Prompt with resume context injected
    LLM / Gemini API-->>FastAPI Backend: Contextual response
    FastAPI Backend-->>Flutter PWA: Response payload

    User->>Flutter PWA: Clicks "Tailor & Sync"
    Flutter PWA->>FastAPI Backend: /resume/tailor (job title & description)
    FastAPI Backend->>LLM / Gemini API: Tailor resume to fit job description
    LLM / Gemini API-->>FastAPI Backend: Tailored resume markdown
    FastAPI Backend->>Google Drive API: Create file & save tailored content
    Google Drive API-->>FastAPI Backend: File Link & Confirmation
    FastAPI Backend-->>Flutter PWA: Sync completed with Google Drive link
    Flutter PWA->>User: Appends Drive link message to chat thread
```

---

## 🛠 Backend Integration

The backend handles AI-based response generation, resume text extraction, PDF parsing, tailoring, and syncing to Google Drive.

### 1. Schema Extensions
The `/mentor/chat` endpoint's request payload accepts an optional `resume_context` containing the extracted text from the user's active resume.

**Location**: `backend/app/api/v1/endpoints/mentor.py`
```python
class MentorMessageRequest(BaseModel):
    message: str
    history: List[dict] = []
    resume_context: Optional[str] = None
```

### 2. Prompt Construction & Context Injection
When the user sends a message and has an active resume uploaded, the request includes the `resume_context`. The backend prepends this context to the system prompt of the career coach LLM session.

**Location**: `backend/app/api/v1/endpoints/mentor.py`
```python
@router.post("/chat")
async def mentor_chat(
    request: MentorMessageRequest,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user),
):
    ...
    system_prompt = "You are Tatvik AI, a professional career coach..."
    if request.resume_context:
        system_prompt += f"\n\nActive Resume Context:\n{request.resume_context}"
    ...
```

---

## 📱 Frontend Integration

The frontend consists of state variables inside `AppState` and user-friendly, high-fidelity UI components.

### 1. AppState (State & Actions)
*   `lastUploadedResumeText`: Stores the text extracted from the PDF. Passed to every `/mentor/chat` request if not empty.
*   `lastUploadedResumeFileName`: Persisted filename of the uploaded PDF to show the active resume context.
*   `isGoogleDriveConnected` / `isCheckingGoogleDriveStatus`: Keeps track of OAuth sync state.
*   `generateAndSyncResumeFromChat(jobTitle, jobDescription)`: Orchestrates the tailoring API call, shows active loading indicator, and appends a Google Drive link to the chat upon successful completion.

### 2. Liquid Glass Chat & Input UI
*   **Active Resume Bar**: Floating translucent bar displayed below the app bar. Displays active resume filename and Google Drive connection status.
*   **Floating Input**: Glassmorphic input field floating above the bottom area with custom border gradients and backdrop blurs.
*   **Attachment Sheet**: A modal bottom drawer triggering:
    1.  *Upload PDF Resume* - Select and parse a PDF.
    2.  *Google Drive Sync Settings* - Check status or launch OAuth authorization.

---

## 🚀 Setup & Execution

### 1. Backend Verification
To run the backend test suite:
```bash
cd backend
.venv/bin/pytest
```

### 2. Frontend Verification
To check the Flutter app analyzer:
```bash
flutter analyze
```
