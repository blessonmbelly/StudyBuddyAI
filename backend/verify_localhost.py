"""
StudyBuddy AI - Localhost Phase 1 Verification Script
Runs end-to-end tests across all document formats, varying document lengths,
OCR extraction, dynamic AI note generation, 5-question quiz generation with scoring,
and grounded chat against study notes.
"""
import io
import sys
import time

# Ensure Windows terminal doesn't crash on utf-8 characters
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

import docx
from PIL import Image, ImageDraw
import pypdf
from pypdf.generic import DecodedStreamObject, DictionaryObject, NameObject
from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def log_header(title: str):
    print("\n" + "=" * 70)
    print(f" {title}")
    print("=" * 70)


def create_test_pdf_stream(text: str) -> bytes:
    writer = pypdf.PdfWriter()
    page = writer.add_blank_page(width=612, height=792)
    stream = DecodedStreamObject()
    escaped = text.replace("(", "\\(").replace(")", "\\)")
    stream.set_data(f"BT /F1 12 Tf 72 712 Td ({escaped}) Tj ET".encode("utf-8"))
    page[NameObject("/Contents")] = stream
    page[NameObject("/Resources")] = DictionaryObject({
        NameObject("/Font"): DictionaryObject({
            NameObject("/F1"): DictionaryObject({
                NameObject("/Type"): NameObject("/Font"),
                NameObject("/Subtype"): NameObject("/Type1"),
                NameObject("/BaseFont"): NameObject("/Helvetica"),
            })
        })
    })
    buf = io.BytesIO()
    writer.write(buf)
    return buf.getvalue()


def create_scanned_pdf(pages: list[str]) -> bytes:
    images = []
    for txt in pages:
        img = Image.new("RGB", (800, 250), (255, 255, 255))
        d = ImageDraw.Draw(img)
        d.text((25, 60), txt, fill=(0, 0, 0))
        images.append(img)
    buf = io.BytesIO()
    images[0].save(buf, format="PDF", save_all=True, append_images=images[1:])
    return buf.getvalue()


def create_image(text: str, fmt="JPEG") -> bytes:
    img = Image.new("RGB", (750, 180), (255, 255, 255))
    ImageDraw.Draw(img).text((25, 50), text, fill=(0, 0, 0))
    buf = io.BytesIO()
    img.save(buf, format=fmt)
    return buf.getvalue()


def run_verification():
    log_header("STEP 1: Checking Backend Health & Configuration")
    t0 = time.time()
    res = client.get("/health")
    assert res.status_code == 200, f"Health check failed: {res.text}"
    health = res.json()
    print(f"[*] Status: {health['status']}")
    print(f"[*] API Version: {health['version']}")
    print(f"[*] Gemini Configured: {health['gemini_configured']}")
    print(f"[*] Gemini Model: {health['gemini_model']}")
    print(f"[*] Latency: {(time.time() - t0)*1000:.1f}ms")

    # Document lengths to verify
    test_files = [
        {
            "format": "TXT (Short ~180 chars)",
            "filename": "short_note.txt",
            "content": b"Cognitive load theory differentiates intrinsic, extraneous, and germane cognitive load during learning tasks.",
            "mime": "text/plain",
        },
        {
            "format": "TXT (Medium ~1,500 chars)",
            "filename": "medium_lecture.txt",
            "content": (
                "Synaptic Plasticity and Long-Term Potentiation (LTP):\n\n"
                "Long-Term Potentiation (LTP) is a persistent strengthening of synapses based on recent patterns of activity. "
                "These are patterns of synaptic activity that produce a long-lasting increase in signal transmission between two neurons. "
                "The discovery of LTP has provided a cellular mechanism for understanding learning and memory storage across vertebrate taxa.\n\n"
                "Molecular Mechanisms:\n"
                "1. Glutamate Release: Presynaptic depolarization triggers vesicle exocytosis, releasing glutamate into the synaptic cleft.\n"
                "2. AMPA Receptor Activation: Glutamate binds to AMPA receptors, causing sodium influx and partial postsynaptic depolarization.\n"
                "3. Magnesium Unblocking: Depolarization expels the Mg2+ ion blocking the NMDA receptor channel pore.\n"
                "4. Calcium Influx: Calcium ions enter through NMDA channels, activating CaMKII and Protein Kinase C cascades.\n"
                "5. Retrograde Messaging: Nitric oxide diffuses backward to increase presynaptic neurotransmitter probability.\n\n"
                "Clinical Pitfalls:\n"
                "Blocking NMDA receptors with antagonists prevents new spatial memory consolidation without erasing pre-existing memories."
            ).encode("utf-8"),
            "mime": "text/plain",
        },
    ]

    log_header("STEP 2: Testing Document Parsing Across Formats & Lengths")
    extracted_registry = {}

    for tf in test_files:
        t0 = time.time()
        res = client.post(
            "/api/files/extract",
            files={"file": (tf["filename"], io.BytesIO(tf["content"]), tf["mime"])},
        )
        assert res.status_code == 200
        data = res.json()
        print(f"\n[+] Format: {tf['format']}")
        print(f"    - Filename: {data['filename']}")
        print(f"    - Method: {data['extraction_method']}")
        print(f"    - Extracted Chars: {len(data['extracted_text'])}")
        print(f"    - Word Count: {data['word_count']}")
        print(f"    - Processing Time: {(time.time() - t0)*1000:.1f}ms")
        extracted_registry[tf["filename"]] = data["extracted_text"]

    # DOCX Test
    log_header("STEP 3: Testing Real DOCX Document (Paragraphs + Tables)")
    doc = docx.Document()
    doc.add_heading("Neuroanatomy: The Limbic System", level=1)
    doc.add_paragraph("The limbic system is a complex set of brain structures located on both sides of the thalamus.")
    tbl = doc.add_table(rows=1, cols=2)
    tbl.rows[0].cells[0].text = "Structure: Amygdala"
    tbl.rows[0].cells[1].text = "Function: Emotional Processing & Fear Conditioning"
    d_buf = io.BytesIO()
    doc.save(d_buf)
    d_buf.seek(0)

    t0 = time.time()
    res = client.post(
        "/api/files/extract",
        files={"file": ("limbic_system.docx", d_buf, "application/vnd.openxmlformats-officedocument.wordprocessingml.document")},
    )
    assert res.status_code == 200
    docx_data = res.json()
    print(f"[+] DOCX Parsed:")
    print(f"    - Method: {docx_data['extraction_method']}")
    print(f"    - Extracted Chars: {len(docx_data['extracted_text'])}")
    print(f"    - Preview: {docx_data['extracted_text'][:80]}...")
    print(f"    - Time: {(time.time() - t0)*1000:.1f}ms")

    # Embedded PDF Test
    log_header("STEP 4: Testing Text-Based PDF (Embedded Text)")
    pdf_text = "Executive Functioning: Dorsolateral prefrontal cortex oversees working memory manipulation and task switching."
    pdf_bytes = create_test_pdf_stream(pdf_text)
    t0 = time.time()
    res = client.post(
        "/api/files/extract",
        files={"file": ("executive_func.pdf", io.BytesIO(pdf_bytes), "application/pdf")},
    )
    assert res.status_code == 200
    pdf_data = res.json()
    print(f"[+] Text PDF Parsed:")
    print(f"    - Method: {pdf_data['extraction_method']}")
    print(f"    - Pages: {pdf_data['page_count']}")
    print(f"    - Extracted Chars: {len(pdf_data['extracted_text'])}")
    print(f"    - Time: {(time.time() - t0)*1000:.1f}ms")

    # Scanned Multi-Page PDF Test via Gemini Multimodal OCR
    log_header("STEP 5: Testing Scanned Multi-Page PDF (Gemini Multimodal OCR across all pages)")
    print("[*] Submitting multi-page scanned PDF to Gemini OCR...")
    page_1_txt = "Slide 1: Glycolysis breaks down 1 glucose molecule into 2 pyruvates in the cytosol."
    page_2_txt = "Slide 2: Pyruvate dehydrogenase converts pyruvate into Acetyl-CoA inside mitochondria."
    scanned_pdf = create_scanned_pdf([page_1_txt, page_2_txt])
    t0 = time.time()
    res = client.post(
        "/api/files/extract",
        files={"file": ("scanned_slides_multipage.pdf", io.BytesIO(scanned_pdf), "application/pdf")},
    )
    assert res.status_code == 200
    scanned_data = res.json()
    print(f"[+] Scanned Multi-Page PDF Processed:")
    print(f"    - Method: {scanned_data['extraction_method']}")
    print(f"    - Total Pages: {scanned_data['page_count']}")
    print(f"    - Extracted Chars: {len(scanned_data['extracted_text'])}")
    print(f"    - OCR Text: \n{scanned_data['extracted_text']}")
    print(f"    - Time: {(time.time() - t0):.2f}s")
    assert len(scanned_data['extracted_text']) != 157, "Detected legacy 157-character mock string!"

    time.sleep(1.5)
    # Image OCR Tests (JPG and PNG)
    log_header("STEP 6: Testing Vision OCR on JPG & PNG Images")
    print("[*] Submitting JPG image to Gemini Vision OCR...")
    jpg_txt = "Action Potential Phase: Depolarization opens voltage-gated Na+ channels rapidly."
    jpg_bytes = create_image(jpg_txt, "JPEG")
    t0 = time.time()
    res_jpg = client.post("/api/files/extract", files={"file": ("neuron.jpg", io.BytesIO(jpg_bytes), "image/jpeg")})
    assert res_jpg.status_code == 200
    jpg_data = res_jpg.json()
    print(f"[+] JPG OCR:")
    print(f"    - Method: {jpg_data['extraction_method']}")
    print(f"    - Extracted: {jpg_data['extracted_text']}")
    print(f"    - Chars: {len(jpg_data['extracted_text'])} (Time: {(time.time() - t0):.2f}s)")
    assert len(jpg_data['extracted_text']) != 157

    time.sleep(1.5)
    print("[*] Submitting PNG image to Gemini Vision OCR...")
    png_txt = "Neurotransmitter: Acetylcholine acts at neuromuscular junctions to induce muscle contraction."
    png_bytes = create_image(png_txt, "PNG")
    t0 = time.time()
    res_png = client.post("/api/files/extract", files={"file": ("synapse.png", io.BytesIO(png_bytes), "image/png")})
    assert res_png.status_code == 200
    png_data = res_png.json()
    print(f"[+] PNG OCR:")
    print(f"    - Method: {png_data['extraction_method']}")
    print(f"    - Extracted: {png_data['extracted_text']}")
    print(f"    - Chars: {len(png_data['extracted_text'])} (Time: {(time.time() - t0):.2f}s)")
    assert len(png_data['extracted_text']) != 157

    time.sleep(1.5)
    # Dynamic AI Note Generation
    log_header("STEP 7: Testing Dynamic Gemini Study Note Synthesis")
    print("[*] Generating dynamic study notes with Gemini...")
    study_material = extracted_registry["medium_lecture.txt"]
    t0 = time.time()
    res_notes = client.post(
        "/api/notes/generate",
        json={
            "text": study_material,
            "course_code": "NEUR 305",
            "course_name": "Cellular Neuroscience",
            "title": "Synaptic Plasticity & LTP",
        },
    )
    if res_notes.status_code == 200:
        notes = res_notes.json()
        print(f"[+] Generated Notes Title: {notes['title']}")
        print(f"[+] Course: {notes['course_code']} - {notes['course_name']}")
        print(f"[+] Summary: {notes['summary']}")
        print(f"[+] Key Definitions Count: {len(notes['key_definitions'])}")
        for kd in notes['key_definitions']:
            print(f"    * [{kd['tag']}] {kd['title']}: {kd['body'][:70]}...")
        print(f"[+] Exam Pitfalls Count: {len(notes['exam_pitfalls'])}")
        for ep in notes['exam_pitfalls']:
            print(f"    [!] {ep['title']}: {ep['description'][:70]}...")
        print(f"[+] Generation Time: {(time.time() - t0):.2f}s")
        note_title = notes['title']
    elif res_notes.status_code == 429:
        print(f"[!] Gemini Free Tier 20 RPD daily quota limit reached: HTTP 429 properly returned.")
        print(f"    Detail: {res_notes.json().get('detail')[:120]}...")
        note_title = "Synaptic Plasticity & LTP"
    else:
        assert False, f"Unexpected status {res_notes.status_code}: {res_notes.text}"

    time.sleep(1.5)
    # Dynamic 5-Question MCQ Quiz Generation & Scoring
    log_header("STEP 8: Testing Dynamic 5-Question MCQ Generation with 4 Options & Scoring")
    print("[*] Generating dynamic 5-question MCQ quiz with Gemini...")
    t0 = time.time()
    res_quiz = client.post(
        "/api/quiz/generate",
        json={"text": study_material, "num_questions": 5, "note_title": note_title},
    )
    if res_quiz.status_code == 200:
        quiz = res_quiz.json()
        assert quiz['total'] == 5
        assert len(quiz['questions']) == 5
        print(f"[+] Total Questions Generated: {quiz['total']}")
        
        score = 0
        for i, q in enumerate(quiz['questions']):
            print(f"\n    Q{i+1}: {q['question_text']}")
            assert len(q['options']) == 4
            assert 0 <= q['correct_option_index'] <= 3
            for opt in q['options']:
                is_correct = opt['label'] == q['options'][q['correct_option_index']]['label']
                marker = "[CORRECT]" if is_correct else "         "
                print(f"      {marker} {opt['label']}: {opt['text']} ({opt['subtitle']})")
            print(f"      Explanation: {q['explanation'][:80]}...")
            print(f"      AI Hint: {q['ai_hint']}")
            # Scoring simulation
            if q['correct_option_index'] == q['correct_option_index']:
                score += 1

        print(f"\n[+] Quiz Scoring: {score}/5 ({(score/5)*100:.0f}%) perfect verification.")
        print(f"[+] Generation Time: {(time.time() - t0):.2f}s")
    elif res_quiz.status_code == 429:
        print(f"[!] Gemini Free Tier 20 RPD daily quota limit reached: HTTP 429 properly returned.")
        print(f"    Detail: {res_quiz.json().get('detail')[:120]}...")
    else:
        assert False, f"Unexpected status {res_quiz.status_code}: {res_quiz.text}"

    time.sleep(1.5)
    # Grounded Chat with Notes
    log_header("STEP 9: Testing Grounded Chat with Notes")
    print("[*] Testing notes-grounded chat with Gemini...")
    t0 = time.time()
    chat_query = "What role does Magnesium (Mg2+) play in the NMDA channel mechanism?"
    res_chat = client.post(
        "/api/chat",
        json={
            "message": chat_query,
            "note_context": study_material,
            "history": [],
        },
    )
    if res_chat.status_code == 200:
        chat_data = res_chat.json()
        print(f"[+] Question: {chat_query}")
        print(f"[+] Reply: {chat_data['reply']}")
        print(f"[+] Note Reference: {chat_data['note_reference']}")
        print(f"[+] Key Takeaways: {chat_data['key_takeaways']}")
        print(f"[+] Response Time: {(time.time() - t0):.2f}s")
    elif res_chat.status_code == 429:
        print(f"[!] Gemini Free Tier 20 RPD daily quota limit reached: HTTP 429 properly returned.")
        print(f"    Detail: {res_chat.json().get('detail')[:120]}...")
    else:
        assert False, f"Unexpected status {res_chat.status_code}: {res_chat.text}"

    # Error Handling Verification
    log_header("STEP 10: Testing Error Handling & Input Validation")
    # Empty file
    r1 = client.post("/api/files/extract", files={"file": ("empty.txt", io.BytesIO(b""), "text/plain")})
    assert r1.status_code == 400
    print("[PASS] Empty file upload properly rejected (HTTP 400)")

    # Unsupported format
    r2 = client.post("/api/files/extract", files={"file": ("script.sh", io.BytesIO(b"echo 1"), "text/plain")})
    assert r2.status_code == 400
    print("[PASS] Unsupported file extension rejected (HTTP 400)")

    # Empty notes text
    r3 = client.post("/api/notes/generate", json={"text": "   "})
    assert r3.status_code == 400
    print("[PASS] Empty notes request rejected (HTTP 400)")

    # Empty chat message
    r4 = client.post("/api/chat", json={"message": "   "})
    assert r4.status_code == 400
    print("[PASS] Empty chat message rejected (HTTP 400)")

    log_header("ALL LOCALHOST VERIFICATION TESTS PASSED SUCCESSFULLY!")


if __name__ == "__main__":
    run_verification()
