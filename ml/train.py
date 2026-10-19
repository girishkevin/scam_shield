"""
Train the Scam Shield text classifier and export it for the Flutter app.

Model: TF-IDF (word 1-2 grams) + logistic regression.
Output: assets/ml/scam_model.json  (plain numbers, no native ML library needed)

Run from the project root:   python ml/train.py
"""
import json
import re
from pathlib import Path

import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parent
DATA_DIR = ROOT / "data"
OUT_PATH = ROOT.parent / "assets" / "ml" / "scam_model.json"

UCI_FILE = DATA_DIR / "SMSSpamCollection"       # optional (public English dataset)
INDIA_FILE = DATA_DIR / "india_messages.txt"    # our own India-specific examples

INDIA_WEIGHT = 4.0  # India examples count more: there are far fewer of them

# ---- Text preparation. The Dart app repeats these exact steps. -------------
URL_RE = re.compile(r"(?:https?://|www\.)[^ \t\r\n]+")
NUM_RE = re.compile(r"[0-9]+")
TOKEN_PATTERN = r"[a-z0-9_]{2,}"


def preprocess(text: str) -> str:
    t = text.lower()
    t = URL_RE.sub(" urltoken ", t)
    t = NUM_RE.sub(" numtoken ", t)
    return t


# ---- Data loading -----------------------------------------------------------
def load_uci(path: Path):
    rows = []
    if not path.exists():
        print(f"[info] {path.name} not found, training on India examples only.")
        return rows
    with open(path, encoding="utf-8", errors="ignore") as f:
        for line in f:
            if "\t" not in line:
                continue
            label, text = line.rstrip("\n").split("\t", 1)
            rows.append((1 if label.strip() == "spam" else 0, text.strip(), "uci"))
    return rows


def load_india(path: Path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "|" not in line:
                continue
            label, text = line.split("|", 1)
            label = label.strip().lower()
            if label not in ("scam", "legit"):
                continue
            rows.append((1 if label == "scam" else 0, text.strip(), "india"))
    return rows


def make_vectorizer():
    return TfidfVectorizer(
        preprocessor=preprocess,
        lowercase=False,
        token_pattern=TOKEN_PATTERN,
        ngram_range=(1, 2),
        min_df=2,
        max_features=6000,
        sublinear_tf=True,
        norm="l2",
    )


def make_classifier():
    return LogisticRegression(C=4.0, class_weight="balanced", max_iter=2000)


def main():
    rows = load_uci(UCI_FILE) + load_india(INDIA_FILE)
    labels = np.array([r[0] for r in rows])
    texts = [r[1] for r in rows]
    sources = np.array([r[2] for r in rows])
    weights = np.where(sources == "india", INDIA_WEIGHT, 1.0)

    n_scam = int(labels.sum())
    print(f"Loaded {len(rows)} messages: {n_scam} scam, {len(rows) - n_scam} legit")
    print(f"  UCI: {int((sources == 'uci').sum())}   India: {int((sources == 'india').sum())}")

    # ---- Honest evaluation on a held-out 20% -------------------------------
    idx = np.arange(len(rows))
    train_idx, test_idx = train_test_split(
        idx, test_size=0.2, random_state=42, stratify=labels
    )
    vec = make_vectorizer()
    X_train = vec.fit_transform([texts[i] for i in train_idx])
    clf = make_classifier()
    clf.fit(X_train, labels[train_idx], sample_weight=weights[train_idx])

    X_test = vec.transform([texts[i] for i in test_idx])
    pred = clf.predict(X_test)
    y_test = labels[test_idx]

    print("\n=== Held-out test set (all data) ===")
    print(classification_report(y_test, pred, target_names=["legit", "scam"], digits=3))
    print("Confusion matrix [rows=true legit/scam, cols=predicted legit/scam]:")
    print(confusion_matrix(y_test, pred))

    india_mask = sources[test_idx] == "india"
    if india_mask.sum() > 0:
        print("\n=== Held-out test set (India examples only) ===")
        print(classification_report(
            y_test[india_mask], pred[india_mask],
            labels=[0, 1], target_names=["legit", "scam"], digits=3, zero_division=0,
        ))

    # ---- Final model: retrain on everything and export ---------------------
    vec = make_vectorizer()
    X = vec.fit_transform(texts)
    clf = make_classifier()
    clf.fit(X, labels, sample_weight=weights)

    idf = vec.idf_
    coef = clf.coef_[0]
    terms = {
        term: [round(float(idf[i]), 8), round(float(coef[i]), 8)]
        for term, i in sorted(vec.vocabulary_.items())
    }

    def proba(text: str) -> float:
        return float(clf.predict_proba(vec.transform([text]))[0][1])

    # Texts used by the Flutter test to prove Dart gives the same answers.
    parity_texts = [
        "Dear customer, your SBI account will be blocked today. Update KYC now: http://sbi-kyc-update.xyz/login",
        "123456 is your OTP for login. Do not share it with anyone.",
        "Share your OTP to receive your refund.",
        "Hi, are we still meeting for lunch tomorrow?",
        "Congratulations! You have won Rs 25,00,000 in the lucky draw. Claim your prize now.",
        "Rs 500.00 debited from A/c XX1234 via UPI. If not you, call your bank helpline.",
        "Aapka account band ho jayega, turant verify karein",
        "Your parcel is on hold. Pay Rs 49 at bit.ly/parcel-pay to release it.",
        "\u20b9500 \u0915\u094d\u0930\u0947\u0921\u093f\u091f hello world",
        "ok",
        "",
    ]
    test_vectors = [{"text": t, "p": round(proba(t), 8)} for t in parity_texts]

    model = {
        "version": 1,
        "description": "TF-IDF (word 1-2 grams) + logistic regression scam text classifier",
        "intercept": round(float(clf.intercept_[0]), 8),
        "terms": terms,
        "test_vectors": test_vectors,
    }

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        json.dump(model, f, ensure_ascii=False, separators=(",", ":"))
    print(f"\nSaved {OUT_PATH}  ({len(terms)} terms, {OUT_PATH.stat().st_size / 1024:.0f} KB)")

    # ---- Quick sanity check: read these and judge them yourself -------------
    print("\n=== Sanity check (probability that the message is a scam) ===")
    samples = [
        "123456 is your OTP for login. Do not share it with anyone.",
        "Rs 800.00 debited from A/c XX4821 via UPI. Avl Bal Rs 9,200.",
        "Your Amazon order has been delivered.",
        "Your SBI KYC is expired. Update now at http://sbi-kyc.xyz or your account will be blocked.",
        "Share your OTP to claim your lucky draw prize of Rs 10 lakh.",
        "Police case registered against you. Join video call or be arrested.",
    ]
    for s in samples:
        print(f"  {proba(s):5.2f}  {s}")


if __name__ == "__main__":
    main()
