import json
import sys

# Ensure UTF-8 output on Windows console
if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

BASE_URL = "http://127.0.0.1:8000/api/files/organize"

docs = [
    {
        "filename": "lecture_bio_ch6_photosynthesis.pdf",
        "text": """Photosynthesis occurs in chloroplasts where chlorophyll absorbs sunlight. In the light-dependent reactions, water is photolyzed producing oxygen and NADPH plus ATP. The Calvin Cycle (light-independent reactions) in the stroma fixes carbon dioxide into G3P using RuBisCO. In C4 plants like corn and sugarcane, spatial separation of carbon fixation occurs in mesophyll and bundle sheath cells to minimize photorespiration."""
    },
    {
        "filename": "cs301_db_systems_normalization.docx",
        "text": """Database normalization is the process of structuring a relational database in accordance with normal forms to reduce data redundancy and improve data integrity. First Normal Form (1NF) eliminates duplicate columns and requires atomic values. Second Normal Form (2NF) removes partial dependencies on a composite primary key. Third Normal Form (3NF) removes transitive dependencies. Boyce-Codd Normal Form (BCNF) strictly requires every determinant to be a candidate key."""
    },
    {
        "filename": "econ_macro_monetary_policy.txt",
        "text": """Monetary policy is enacted by central banks by adjusting the reserve ratio, discount rate, and conducting open market operations. The Keynesian transmission mechanism suggests that lowering nominal interest rates increases investment spending and shifts aggregate demand outward. The expenditure multiplier reflects how an initial change in government expenditure ripples through the economy based on the marginal propensity to consume (MPC)."""
    },
    {
        "filename": "unreadable_handwritten_scan.jpg",
        "text": "?? ?? ??? illegible marks."
    }
]

def organize_request(payload):
    try:
        import urllib.request
        req = urllib.request.Request(
            BASE_URL,
            headers={"Content-Type": "application/json"},
            data=json.dumps(payload).encode("utf-8"),
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception:
        from fastapi.testclient import TestClient
        from main import app
        client = TestClient(app)
        res = client.post("/api/files/organize", json=payload)
        return res.json()

def main():
    print("=" * 65)
    print("SMART DOCUMENT ORGANIZATION VERIFICATION")
    print("=" * 65)
    for d in docs:
        res = organize_request({"text": d["text"], "filename": d["filename"]})
        print(f"\n=== Document: {d['filename']} ===")
        print(f"Title:             {res.get('title')}")
        print(f"Subject:           {res.get('subject')}")
        print(f"Topics:            {res.get('topics')}")
        print(f"Processing Status: {res.get('processing_status')}")

if __name__ == "__main__":
    main()
