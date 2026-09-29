"""Genera assets/demo/demo_profile.json a partir del contenido real.

El perfil de demostración usa las mismas claves que UserState.toJson() en
lib/domain/records/records.dart. Es de solo lectura y nunca se mezcla con los
datos del usuario. Ejecutar desde la raíz del proyecto:  python3 tool/generate_demo.py
"""
import json
import re
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "assets/content/es"
OUT = ROOT / "assets/demo/demo_profile.json"

catalog = json.loads((CONTENT / "catalog.json").read_text(encoding="utf-8"))
dist = {d["id"]: d for d in json.loads((CONTENT / "distinctions.json").read_text(encoding="utf-8"))["distinctions"]}
EXPS = {e["id"]: json.loads((CONTENT / f"experiences/{e['id']}.json").read_text(encoding="utf-8")) for e in catalog["experiences"]}

BASE = datetime(2026, 9, 1, 18, 0, 0)


def at(day, minute=0):
    return (BASE + timedelta(days=day, minutes=minute)).isoformat()


def conf(v):
    return ["sin inclinarme", "me inclino", "con bastante seguridad", "con mucha seguridad"][min(abs(v), 3)]


def stance(exp, v, t):
    j = exp["judgment"]
    return {"value": v, "left": j["left"]["label"], "right": j["right"]["label"], "at": t}


def label(s):
    return "No lo sé" if s["value"] == 0 else (s["left"] if s["value"] < 0 else s["right"])


def reason(exp, rid, t):
    r = next(x for x in exp["reasons"] if x["id"] == rid)
    return {"id": r["id"], "text": r["text"], "tags": r["tags"], "other": None, "at": t}


def question(exp, qid):
    return next(q for q in exp["questions"] if q["id"] == qid)


def render(text, values):
    def sub(m):
        k = m.group(1)
        if k not in values:
            raise KeyError(f"falta {k} en {text}")
        return values[k]
    return re.sub(r"\{([a-zA-Z_:.0-9]+)\}", sub, text)


state = {"experiences": {}, "notebook": []}
CUR = {}


def begin(eid, rid, initial):
    """Valores de la experiencia en curso: {esta_razon} y {esta_postura}."""
    exp = EXPS[eid]
    CUR.clear()
    CUR["esta_razon"] = next(x for x in exp["reasons"] if x["id"] == rid)["text"]
    CUR["esta_postura"] = label(stance(exp, initial, ""))
records = {}


def memory_values(src, exp_id):
    """Replica MemoryEngine: cita literal del registro, con su referencia."""
    if src == "onboarding":
        s = ONB["stance"]
        ref = {"exp": "onboarding", "field": "onboarding", "at": ONB["completedAt"], "quote": label(s)}
        return {"postura": label(s), "seguridad": conf(s["value"])}, {"postura": ref, "seguridad": ref}
    if src == "hollow":
        done = [p for k, p in records.items() if k != exp_id and p.get("cruza") and p["cruza"].get("final")]
        done.sort(key=lambda p: p["id"])
        k = sum(1 for p in done if p["cruza"]["final"] in ("reconocible", "fuerte"))
        ref = {"exp": done[0]["id"], "field": "cruza", "at": done[0]["cruza"]["completedAt"],
               "quote": ", ".join(EXPS[p["id"]]["title"] for p in done)}
        return {"n": str(len(done)), "k": str(k)}, {"n": ref, "k": ref}
    p = records[src]
    s = p["finalStance"]
    r = p["reason"]
    sref = {"exp": src, "field": "stance.final", "at": s["at"], "quote": label(s)}
    rref = {"exp": src, "field": "reason", "at": r["at"], "quote": r["text"]}
    return ({"titulo": EXPS[src]["title"], "postura": label(s), "seguridad": conf(s["value"]), "razon": r["text"]},
            {"postura": sref, "seguridad": sref, "razon": rref})


def socratic(exp, qid, answer_id, answer_label, t, trigger=None, memory=None, extra=None, follow=False):
    q = question(exp, qid)
    values, refs = ({}, {})
    if memory:
        values, refs = memory_values(memory, exp["id"])
    values = {**CUR, **values, **(extra or {})}
    text = render(q["text"], values)
    used = re.findall(r"\{([a-zA-Z_:.0-9]+)\}", q["text"])
    rlist = []
    for k in used:
        if k in refs and refs[k] not in rlist:
            rlist.append(refs[k])
    trig = trigger or next(tr["id"] for tr in exp["triggers"] if tr["question"] == qid)
    return {"trigger": trig, "question": qid, "kind": q["kind"], "text": text, "refs": rlist,
            "answer": answer_id, "answerLabel": answer_label, "followUp": follow, "at": t}


def implication(exp, qid, accept, t, trigger):
    q = question(exp, qid)
    return {"trigger": trigger, "question": "implication", "kind": "implication", "text": q["implication"],
            "refs": [], "answer": "acepto" if accept else "noDelTodo",
            "answerLabel": "Sí, lo acepto" if accept else "No del todo", "followUp": True, "at": t}


def test_record(exp, did, holds, t, trigger):
    d = next(x for x in exp["differences"] if x["id"] == did)
    return {"trigger": trigger, "question": f"test:{did}", "kind": "test", "text": d["test"], "refs": [],
            "answer": "sostengo" if holds else "dudo", "answerLabel": "Sí, lo sostengo" if holds else "No estoy seguro",
            "followUp": True, "at": t}


def matizar(exp, did, firmness, t, idx):
    d = next(x for x in exp["differences"] if x["id"] == did)
    di = dist.get(d["distinction"]) if d["distinction"] else None
    entry = {
        "id": f"demo_n{idx}", "distinctionId": di["id"] if di else "own", "experienceId": exp["id"],
        "userWords": d["text"], "everydayName": di["everydayName"] if di else "",
        "shortExplanation": di["shortExplanation"] if di else "",
        "philosophicalRelation": di["philosophicalRelation"] if di else "",
        "referenceIds": di["referenceIds"] if di else [], "firmness": firmness, "at": t,
    }
    state["notebook"].append(entry)
    return {"outcome": "matizar", "difference": did, "differenceText": d["text"], "firmness": firmness,
            "notebookEntry": entry["id"], "revisionTarget": None, "noAplicaText": None, "at": t}


def outcome(kind, t, target=None, text=None):
    return {"outcome": kind, "difference": None, "differenceText": None, "firmness": None,
            "notebookEntry": None, "revisionTarget": target, "noAplicaText": text, "at": t}


def cruza(exp, target, placements, strength, agreement, t, chosen=False):
    """placements: lista de intentos {slot: pieza}; se evalúa como CruzaEngine."""
    side = exp["cruza"][target]
    pieces = {p["id"]: p for p in side["pieces"]}
    attempts = []
    for i, pl in enumerate(placements):
        missing, filled, own, mismatch = [], 0, False, False
        for s in ["S1", "S2", "S3", "S4"]:
            pid = pl.get(s)
            if not pid or pid not in pieces:
                missing.append(s)
                continue
            filled += 1
            p = pieces[pid]
            if p["kind"] != "valid":
                own = True
            elif s not in p["slots"]:
                mismatch = True
        if own or filled < 2:
            st = "noRepresenta"
        elif mismatch or any(s != "S4" for s in missing):
            st = "parcial"
        elif "S4" in missing:
            st = "reconocible"
        else:
            st = "fuerte"
        attempts.append({"placement": pl, "state": st, "missing": missing, "at": t})
    table = sorted({pid for pl in placements for pid in pl.values()})
    return {"target": target, "chosen": chosen, "table": table, "placement": placements[-1], "discarded": [],
            "events": [], "note": None, "attempts": attempts, "final": attempts[-1]["state"],
            "strength": strength, "agreement": agreement, "completedAt": t}


def done(eid, day, probes, initial, rid, soc, tension, cr, final):
    exp = EXPS[eid]
    rec = {
        "id": eid, "status": "completed", "stage": "done", "startedAt": at(day), "completedAt": at(day, 14),
        "contentVersion": catalog["contentVersion"], "probes": probes,
        "initialStance": stance(exp, initial, at(day, 2)), "reason": reason(exp, rid, at(day, 3)),
        "socratic": soc, "active": None, "tension": tension, "pendingDifference": None, "cruza": cr,
        "finalStance": stance(exp, final, at(day, 13)),
    }
    records[eid] = rec
    state["experiences"][eid] = rec



ONB = {"stance": {"value": 2, "left": "No", "right": "Sí", "at": at(0)}, "completedAt": at(0)}


# --- Réplica de FactResolver + ConditionEvaluator (lib/engine/rules/rules.dart)
def fact(path, eid, current):
    parts = path.split(".")
    head = parts[0]
    if head == "onboarding":
        return ONB["stance"]["value"] if len(parts) > 1 and parts[1] == "stance" else None
    if head == "hollow":
        recs = [p for k, p in records.items() if k != eid and p.get("cruza") and p["cruza"].get("final")]
        if parts[1] == "count":
            return len(recs)
        if parts[1] == "recognized":
            return sum(1 for p in recs if p["cruza"]["final"] in ("reconocible", "fuerte"))
        return None
    is_this = head == "this"
    p = current if is_this else records.get(head)
    if len(parts) >= 2 and parts[1] == "status":
        return "completed" if (not is_this and p) else ("inProgress" if is_this else "notStarted")
    if p is None:
        return None
    f = parts[1:]
    if f[0] == "stance":
        s = p.get("initialStance" if f[1] == "initial" else "finalStance")
        return s["value"] if s else None
    if f[0] == "reason":
        r = p.get("reason")
        return None if not r else (r["id"] if f[1] == "id" else r["tags"])
    if f[0] == "tension":
        t = p.get("tension")
        return None if not t else (t["outcome"] if f[1] == "outcome" else t["revisionTarget"])
    if f[0] == "probe":
        return (p.get("probes", {}).get(f[1]) or {}).get(f[2])
    if f[0] == "answer":
        return next((r["answer"] for r in p.get("socratic", []) if r["question"] == f[1]), None)
    return None


def ev(c, eid, current):
    if not c:
        return True
    if "all" in c:
        return all(ev(x, eid, current) for x in c["all"])
    if "any" in c:
        return any(ev(x, eid, current) for x in c["any"])
    if "not" in c:
        return not ev(c["not"], eid, current)
    a = fact(c["fact"], eid, current)
    op, v = c.get("op", "eq"), c.get("value")
    if op == "exists":
        return a is not None
    if op == "notExists":
        return a is None
    if a is None:
        return False
    eq = lambda x, y: x == y if isinstance(x, (int, float)) and isinstance(y, (int, float)) and not isinstance(x, bool) else str(x).lower() == str(y).lower()
    if op == "eq": return eq(a, v)
    if op == "ne": return not eq(a, v)
    if op == "in": return any(eq(a, x) for x in v)
    if op == "notIn": return not any(eq(a, x) for x in v)
    if op in ("gt", "gte", "lt", "lte"):
        if not isinstance(a, (int, float)): return False
        return {"gt": a > v, "gte": a >= v, "lt": a < v, "lte": a <= v}[op]
    if op == "containsAny": return isinstance(a, list) and any(x in v for x in a)
    return False


def first_question(eid, current):
    """Réplica de SocraticEngine.selectFirst: primera regla aplicable y redactable."""
    exp = EXPS[eid]
    for t in sorted(exp["triggers"], key=lambda t: t["priority"]):
        if not ev(t["condition"], eid, current):
            continue
        mem = t.get("memory")
        try:
            if mem:
                src = mem["source"]
                if src not in ("onboarding", "hollow"):
                    pr = records.get(src)
                    if not pr or (mem.get("excludeIfRevised", True) and (pr.get("tension") or {}).get("revisionTarget") == "principio"):
                        continue
            return t
        except KeyError:
            continue
    return None


def run(eid, day, probes, initial, rid, plan, target_placements, strength, agreement, final, chosen_side=None):
    """Recorre una experiencia como lo haría ExperienceEngine y la deja completada."""
    exp = EXPS[eid]
    begin(eid, rid, initial)
    current = {"probes": probes, "initialStance": stance(exp, initial, at(day, 2)), "reason": reason(exp, rid, at(day, 3)), "socratic": []}
    soc, tension = [], None
    t = first_question(eid, current)
    if t:
        q = question(exp, t["question"])
        mem = (t.get("memory") or {}).get("source")
        extra = {}
        if "{fact:" in q["text"]:
            for k in re.findall(r"\{fact:([a-zA-Z_.0-9]+)\}", q["text"]):
                extra["fact:" + k] = str(fact(k, eid, current))
        if q["kind"] == "tension":
            kind = plan.get("tension", "mantener")
            labels = {"mantener": "Mantener", "matizar": "Matizar", "revisar": "Revisar", "noAplica": "Esta pregunta no aplica"}
            soc.append(socratic(exp, q["id"], kind, labels[kind], at(day, 4), trigger=t["id"], memory=mem, extra=extra))
            if kind == "mantener":
                accept = plan.get("accept", True)
                soc.append(implication(exp, q["id"], accept, at(day, 5), t["id"]))
                if accept:
                    tension = outcome("mantener", at(day, 5))
                else:
                    kind = "matizar"
            if kind == "matizar":
                did = plan.get("difference") or exp["differences"][0]["id"]
                holds = plan.get("holds", True)
                if len(soc) < 2:
                    soc.append(test_record(exp, did, holds, at(day, 6), t["id"]))
                tension = matizar(exp, did, "sostenida" if holds else "dudosa", at(day, 6), len(state["notebook"]) + 1)
            elif kind == "revisar":
                tension = outcome("revisar", at(day, 5), target=plan.get("target", "juicio"))
            elif kind == "noAplica":
                tension = outcome("noAplica", at(day, 5), text=plan.get("text"))
        elif q["kind"] == "assumption":
            aid = plan.get("assumption", "si")
            labels = {"si": "Sí, lo creo", "noDelTodo": "No del todo", "fundamento": "Así lo valoro, sin más"}
            soc.append(socratic(exp, q["id"], aid, labels[aid], at(day, 4), trigger=t["id"], memory=mem, extra=extra))
        else:
            ans = plan.get("answer")
            a = next((x for x in q["answers"] if x["id"] == ans), q["answers"][0])
            soc.append(socratic(exp, q["id"], a["id"], a["label"], at(day, 4), trigger=t["id"], memory=mem, extra=extra))
    target = chosen_side or ("right" if initial < 0 else "left")
    cr = cruza(exp, target, [dict((s, pid.replace("X_", f"{eid[:2]}_{target[0]}_")) for s, pid in pl.items()) for pl in target_placements],
               strength, agreement, at(day, 10), chosen=chosen_side is not None)
    done(eid, day, probes, initial, rid, soc, tension, cr, final)
    used = soc[0]["question"] if soc else "—"
    print(f"  {eid}: pregunta {used}, recuerdo: {[r['exp'] for r in soc[0]['refs']] if soc else []}, CRUZA {cr['final']}")


FULL = {"S1": "X_v1", "S2": "X_r1", "S3": "X_c", "S4": "X_respg"}
CORE = {"S1": "X_v1", "S2": "X_r1", "S3": "X_c"}

run("e1_mismo_descuido", 0, {"e1_gemelos": {"ana": 2, "beto": 3, "diff": 1}}, -2, "e1_r_decision",
    {"tension": "matizar", "difference": "e1_dif_reparar", "answer": "mismo"}, [FULL], 4, 2, -1)
run("e2_promesa_sabado", 1, {"e2_secreto": {"choice": "falle"}}, 1, "e2_r_hermana",
    {"tension": "mantener", "accept": True}, [CORE], 3, 2, 1)
run("e3_lo_que_viste", 2, {"e3_anillos": {"companero": -1, "desconocido": 1}}, 1, "e3_r_mismo_trato",
    {"tension": "revisar", "target": "juicio", "assumption": "noDelTodo"}, [FULL], 5, 2, -1)
run("e4_verdad_incomoda", 3, {"e4_escalera": {"line": 3}}, -3, "e4_r_derecho",
    {"tension": "matizar", "difference": "e4_dif_no_decir"}, [{"S1": "X_v1", "S3": "X_c"}], 2, 1, -3)
run("e5_cien_becas", 4,
    {"e5_simulador": {"attempts": 7, "north": 55, "south": 45, "reachedI1": True, "reachedI2": True, "bothEver": False}},
    1, "e5_r_costo", {"answer": "intencion"}, [CORE], 4, 2, 1)
run("e6_donde_estas", 5,
    {"e6_flujos": {"accepted": 4, "total": 12, "contextual": True, "level": -1, "cells": ["0:2", "1:2", "2:2", "3:2"]}},
    1, "e6_r_seguridad", {"tension": "mantener", "accept": False, "difference": "e6_dif_contexto", "holds": False}, [FULL], 4, 3, 1)
run("e7_la_carta", 6, {"e7_carta": {"marked": 3, "revealed": True}}, 0, "e7_r_efecto",
    {"answer": "acomode"}, [CORE], 3, 3, 1, chosen_side="right")
run("e8_la_copia", 7, {"e8_gradiente": {"stop": 60}}, 1, "e8_r_memoria",
    {"tension": "noAplica", "text": "Para mí depende de qué se reemplaza, no de cuánto.", "answer": "si"},
    [{"S1": "X_v1", "S3": "X_c"}, FULL], 4, 2, 1)
run("e9_sin_haberlo_vivido", 8, {"e9_formas": {"items": 9, "que": 3, "porque": 5, "siente": 1}}, 1, "e9_r_razones",
    {"tension": "mantener", "accept": True, "answer": "si"}, [FULL], 4, 2, 1)

profile = {
    "schemaVersion": 1,
    "contentVersion": catalog["contentVersion"],
    "createdAt": at(0),
    "onboarding": ONB,
    "experiences": state["experiences"],
    "notebook": state["notebook"],
    "notes": {"axis:ax_intencion_resultado": "Me sorprende: en los tres casos pesó más la decisión que el resultado."},
}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(profile, ensure_ascii=False, indent=1), encoding="utf-8")
finals = {k: v["cruza"]["final"] for k, v in state["experiences"].items()}
print("Perfil de demostración:", len(state["experiences"]), "experiencias,", len(state["notebook"]), "distinciones")
print(finals)
