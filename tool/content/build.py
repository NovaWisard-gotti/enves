import json, os, re, itertools, sys
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from library import REFERENCES, DISTINCTIONS
import tramo1, tramo2, tramo3

from pathlib import Path

OUT = str(Path(__file__).resolve().parents[2] / "assets" / "content" / "es")
EXPS = tramo1.EXPERIENCES + tramo2.EXPERIENCES + tramo3.EXPERIENCES


def dump(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)


catalog = {"contentVersion": CONTENT_VERSION, "tramos": CATALOG_TRAMOS,
           "experiences": [{"id": e["id"], "title": e["title"], "question": e["question"],
                            "tramo": e["tramo"], "order": e["order"]} for e in EXPS]}
dump(f"{OUT}/catalog.json", catalog)
dump(f"{OUT}/axes.json", {"axes": AXES})
dump(f"{OUT}/principles.json", {"principles": [{"id": i, "label": l} for i, l in PRINCIPLES]})
dump(f"{OUT}/distinctions.json", {"distinctions": DISTINCTIONS})
dump(f"{OUT}/references.json", {"references": REFERENCES})
dump(f"{OUT}/cruza_common.json", CRUZA_COMMON)
for e in EXPS:
    dump(f"{OUT}/experiences/{e['id']}.json", e)

# ------------------------------------------------------------ validación
errors = []
ref_ids = {r["id"] for r in REFERENCES}
dist_ids = {d["id"] for d in DISTINCTIONS}
axis_ids = {a["id"] for a in AXES}
principle_ids = {p for p, _ in PRINCIPLES}
exp_ids = {e["id"] for e in EXPS}
BAD = re.compile(r"\b(contradicci[oó]n|contradictori[oa]|error|incorrect[oa]|equivocad[oa]|incoherente|te contradijiste|ganaste|perdiste)\b", re.I)
PLACE = re.compile(r"\b(TODO|FIXME|TBD|XXX)\b|(?i:\blorem\b|\bipsum\b|\bplaceholder\b)")
MEM_KEYS = {"titulo", "razon", "postura", "seguridad", "n", "k"}
ALLOWED_KEYS = MEM_KEYS | {"esta_razon", "esta_postura", "respuesta"}


def walk_strings(o):
    if isinstance(o, str):
        yield o
    elif isinstance(o, dict):
        for v in o.values():
            yield from walk_strings(v)
    elif isinstance(o, list):
        for v in o:
            yield from walk_strings(v)


def facts_of(c):
    if not c:
        return []
    out = []
    for k in ("all", "any"):
        if k in c:
            for x in c[k]:
                out += facts_of(x)
    if "not" in c:
        out += facts_of(c["not"])
    if "fact" in c:
        out.append(c["fact"])
    return out


for d in DISTINCTIONS:
    for r in d["referenceIds"]:
        if r not in ref_ids:
            errors.append(f"{d['id']}: referencia {r}")

for e in EXPS:
    eid = e["id"]
    for s in walk_strings(e):
        if PLACE.search(s):
            errors.append(f"{eid}: texto provisional: {s}")
    qids = {q["id"] for q in e["questions"]}
    rids = {r["id"] for r in e["reasons"]}
    pids = {p["id"] for p in e["probes"]}
    for r in e["reasons"]:
        for t in r["tags"]:
            if t not in principle_ids:
                errors.append(f"{eid}: principio {t}")
        if "map" in r and r["map"]["axis"] not in axis_ids:
            errors.append(f"{eid}: eje {r['map']}")
    non_memory = [t for t in e["triggers"] if "memory" not in t]
    if not non_memory:
        errors.append(f"{eid}: sin disparador independiente de memoria")
    for t in e["triggers"]:
        if t["question"] not in qids:
            errors.append(f"{eid}: disparador {t['id']} -> {t['question']}")
        for f in facts_of(t["condition"]):
            head = f.split(".")[0]
            if head not in ("this", "onboarding", "hollow") and head not in exp_ids:
                errors.append(f"{eid}: hecho desconocido {f}")
            if head == "this" and ".probe." in f and f.split(".")[2] not in pids:
                errors.append(f"{eid}: mecánica desconocida {f}")
        if "memory" in t:
            src = t["memory"]["source"]
            if src not in ("onboarding", "hollow") and src not in exp_ids:
                errors.append(f"{eid}: fuente de memoria {src}")
            q = next(q for q in e["questions"] if q["id"] == t["question"])
            keys = set(re.findall(r"\{([a-z_]+)\}", q["text"]))
            if not keys & MEM_KEYS:
                errors.append(f"{eid}: pregunta de memoria sin cita {q['id']}")
    for q in e["questions"]:
        if BAD.search(q["text"]) or BAD.search(q.get("implication", "")):
            errors.append(f"{eid}: palabra no permitida en {q['id']}")
        for k in re.findall(r"\{([a-z_]+)\}", q["text"]):
            if k not in ALLOWED_KEYS:
                errors.append(f"{eid}: marcador {k} en {q['id']}")
        if q["kind"] == "tension" and not q.get("implication"):
            errors.append(f"{eid}: tensión sin implicación {q['id']}")
        if q.get("followUp") and q["followUp"] not in qids:
            errors.append(f"{eid}: followUp {q['followUp']}")
        for a in q["answers"]:
            if a.get("next") and a["next"] not in qids:
                errors.append(f"{eid}: next {a['next']}")
            if "map" in a and a["map"]["axis"] not in axis_ids:
                errors.append(f"{eid}: eje en respuesta")
    for dfn in e["differences"]:
        if dfn["distinction"] and dfn["distinction"] not in dist_ids:
            errors.append(f"{eid}: distinción {dfn['distinction']}")
    for key in ("left", "right"):
        sd = e["cruza"][key]
        pcs = sd["pieces"]
        for slot in ("S1", "S2", "S3", "S4"):
            if not [p for p in pcs if p["kind"] == "valid" and slot in p["slots"]]:
                errors.append(f"{eid}/{key}: ranura {slot} vacía")
        if len([p for p in pcs if p["kind"] == "caricature"]) < 3:
            errors.append(f"{eid}/{key}: caricaturas")
        if not [p for p in pcs if p.get("generic")]:
            errors.append(f"{eid}/{key}: sin respuesta genérica")
        if len(sd["voices"]) != 3:
            errors.append(f"{eid}/{key}: voces")
        for p in pcs:
            for rid in p.get("respondsTo", []):
                if rid not in rids:
                    errors.append(f"{eid}/{key}: respondsTo {rid}")
        ids = [p["id"] for p in pcs]
        if len(ids) != len(set(ids)):
            errors.append(f"{eid}/{key}: ids repetidos")
    for m in e["map"]:
        if m["axis"] not in axis_ids:
            errors.append(f"{eid}: eje {m['axis']}")
        if m["source"] == "probe" and m["probe"] not in pids:
            errors.append(f"{eid}: map probe {m['probe']}")
    tw = e["twist"].get("probe")
    if tw and tw not in pids:
        errors.append(f"{eid}: probe del giro {tw}")
    for r in e["deepDive"]["references"]:
        if r not in ref_ids:
            errors.append(f"{eid}: referencia {r}")

# ------------------------------------------------------ Cien becas: fuerza bruta
cfg = tramo2.FAIRNESS_CONFIG


def metrics(bins, t):
    tp = sum(b["pos"] for b in bins if b["score"] >= t)
    fp = sum(b["n"] - b["pos"] for b in bins if b["score"] >= t)
    fn = sum(b["pos"] for b in bins if b["score"] < t)
    tn = sum(b["n"] - b["pos"] for b in bins if b["score"] < t)
    ppv = tp / (tp + fp) if tp + fp else None
    return ppv, fn / (tp + fn), fp / (fp + tn)


N = cfg["groups"][0]["bins"]; S = cfg["groups"][1]["bins"]
tol = cfg["tolerance"]
thresholds = [b["score"] for b in N]
c1 = c2 = both = 0
for a, b in itertools.product(thresholds, thresholds):
    ma, mb = metrics(N, a), metrics(S, b)
    if ma[0] is None or mb[0] is None:
        continue
    i1 = abs(ma[0] - mb[0]) <= tol + 1e-9
    i2 = abs(ma[1] - mb[1]) <= tol + 1e-9 and abs(ma[2] - mb[2]) <= tol + 1e-9
    c1 += i1; c2 += i2; both += i1 and i2
print(f"Cien becas -> criterio 1: {c1} combinaciones, criterio 2: {c2}, ambos: {both}")
if both or not c1 or not c2:
    errors.append("Cien becas: el conjunto de datos no cumple la condición educativa")

print(f"{len(EXPS)} experiencias, {len(REFERENCES)} referencias, {len(DISTINCTIONS)} distinciones")
if errors:
    print("ERRORES:")
    for x in errors:
        print(" -", x)
    sys.exit(1)
print("Contenido válido.")
