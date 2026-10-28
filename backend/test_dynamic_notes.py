import requests
import json
import sys

# Ensure UTF-8 output on Windows console
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

BASE_URL = "http://127.0.0.1:8000"

DOC1_BIOLOGY = """
Photosynthesis is the fundamental biochemical process by which photoautotrophic organisms convert light energy into chemical energy stored in carbohydrates. The process occurs within chloroplasts in two interconnected stages: the light-dependent reactions within thylakoid membranes and the Calvin cycle (light-independent reactions) in the stroma.

In the thylakoid membrane, photon absorption by chlorophyll a molecules in Photosystem II (P680) excites electrons, which are transferred down an electron transport chain via plastoquinone, cytochrome b6f complex, and plastocyanin to Photosystem I (P700). Water photolysis at the oxygen-evolving complex of PSII splits 2 H2O into 4 H+, 4 e-, and O2, releasing molecular oxygen as a byproduct. 

Proton accumulation in the thylakoid lumen creates an electrochemical proton gradient (chemiosmotic potential) that drives ATP synthase to phosphorylate ADP into ATP. Concurrently, ferredoxin-NADP+ reductase reduces NADP+ to NADPH. Both ATP and NADPH enter the stroma to fuel carbon fixation by ribulose-1,5-bisphosphate carboxylase/oxygenase (RuBisCO) in the Calvin cycle, producing glyceraldehyde-3-phosphate (G3P).
""".strip()

DOC2_DATABASES = """
Relational database normalization is the systematic technique of organizing tables to reduce data redundancy and eliminate undesirable update, insertion, and deletion anomalies. The theory, pioneered by Edgar F. Codd, progresses through formal normal forms based on functional dependencies.

First Normal Form (1NF) mandates that all column values must be atomic (indivisible) and each record must be uniquely identifiable via a primary key, prohibiting repeating groups or nested arrays.
Second Normal Form (2NF) builds upon 1NF by requiring the elimination of partial functional dependencies; every non-prime attribute must be fully functionally dependent on the entirety of every candidate key rather than a proper subset of a composite key.
Third Normal Form (3NF) requires 2NF compliance and the elimination of transitive dependencies: non-key attributes must depend solely on candidate keys and never through another non-key attribute (X -> Y where Y -> Z). Boyce-Codd Normal Form (BCNF) further tightens 3NF by asserting that for every non-trivial functional dependency X -> Y, X must be a superkey.
""".strip()

def post_generate(payload):
    try:
        res = requests.post(f"{BASE_URL}/api/notes/generate", json=payload, timeout=30)
        return res.status_code, res.json()
    except Exception:
        from fastapi.testclient import TestClient
        from main import app
        client = TestClient(app)
        res = client.post("/api/notes/generate", json=payload)
        return res.status_code, res.json()

def run_tests():
    print("=" * 60, flush=True)
    print("TESTING DYNAMIC SHORT NOTE GENERATION WITH TWO DOCUMENTS", flush=True)
    print("=" * 60, flush=True)

    # Test Document 1: Biology
    print("\n[*] Sending Document 1 (Biology - Photosynthesis & Light Reactions)...", flush=True)
    status_code, data1 = post_generate({"text": DOC1_BIOLOGY})
    assert status_code == 200, f"Doc 1 failed with {status_code}: {data1}"

    print("[+] Document 1 Dynamic Response Received:")
    print(f"    - Title:       {data1.get('title')}")
    print(f"    - Course:      {data1.get('course_code')} - {data1.get('course_name')}")
    print(f"    - Summary:     {data1.get('summary')[:100]}...")
    print(f"    - Sections ({len(data1.get('sections', []))}):")
    for s in data1.get("sections", []):
        print(f"      * {s.get('title')}: {len(s.get('bullets', []))} bullet points")
    print(f"    - Definitions ({len(data1.get('key_definitions', []))}):")
    for d in data1.get("key_definitions", [])[:3]:
        print(f"      * [{d.get('tag')}] {d.get('title')}: {d.get('body')[:60]}...")
    print(f"    - Exam Pitfalls ({len(data1.get('exam_pitfalls', []))}):")
    for ep in data1.get("exam_pitfalls", []):
        print(f"      * {ep.get('title')}: {ep.get('concept_a')} vs {ep.get('concept_b')}")

    # Validate Document 1 contents
    d1_title = data1.get("title", "").lower()
    d1_course = (data1.get("course_name", "") + " " + data1.get("course_code", "")).lower()
    d1_all_text = json.dumps(data1).lower()

    assert any(term in d1_title or term in d1_all_text for term in ["photo", "light", "chloroplast", "thylakoid", "calvin"]), \
        "Document 1 title/content should reflect photosynthesis"
    assert "atkinson" not in d1_all_text and "tulving" not in d1_all_text, \
        "Document 1 must not contain mock psychology data"
    print("[PASS] Document 1 successfully generated Biology notes with dynamic concepts.")

    # Test Document 2: Computer Science / Databases
    print("\n[*] Sending Document 2 (Computer Science - Database Normalization)...", flush=True)
    status_code2, data2 = post_generate({"text": DOC2_DATABASES})
    assert status_code2 == 200, f"Doc 2 failed with {status_code2}: {data2}"

    print("[+] Document 2 Dynamic Response Received:")
    print(f"    - Title:       {data2.get('title')}")
    print(f"    - Course:      {data2.get('course_code')} - {data2.get('course_name')}")
    print(f"    - Summary:     {data2.get('summary')[:100]}...")
    print(f"    - Sections ({len(data2.get('sections', []))}):")
    for s in data2.get("sections", []):
        print(f"      * {s.get('title')}: {len(s.get('bullets', []))} bullet points")
    print(f"    - Definitions ({len(data2.get('key_definitions', []))}):")
    for d in data2.get("key_definitions", [])[:3]:
        print(f"      * [{d.get('tag')}] {d.get('title')}: {d.get('body')[:60]}...")
    print(f"    - Exam Pitfalls ({len(data2.get('exam_pitfalls', []))}):")
    for ep in data2.get("exam_pitfalls", []):
        print(f"      * {ep.get('title')}: {ep.get('concept_a')} vs {ep.get('concept_b')}")

    # Validate Document 2 contents
    d2_title = data2.get("title", "").lower()
    d2_all_text = json.dumps(data2).lower()

    assert any(term in d2_title or term in d2_all_text for term in ["normal", "database", "dependency", "1nf", "3nf"]), \
        "Document 2 title/content should reflect database normalization"
    assert "atkinson" not in d2_all_text and "photosynthesis" not in d2_all_text, \
        "Document 2 must not contain mock or previous document data"
    print("[PASS] Document 2 successfully generated Computer Science/Database notes with dynamic concepts.")

    # Verify diversity
    assert data1.get("title") != data2.get("title"), "Titles must be distinctly generated"
    assert data1.get("course_name") != data2.get("course_name"), "Course names must be distinctly inferred"

    print("\n" + "=" * 60)
    print("SUCCESS: BOTH DOCUMENTS DYNAMICALLY SYNTHESIZED AND VERIFIED!")
    print("=" * 60)

if __name__ == "__main__":
    run_tests()
