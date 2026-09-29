"""Helpers para escribir el contenido de Envés de forma compacta y consistente."""

CONTENT_VERSION = "1.0.0"


def leaf(fact, op, value=None):
    d = {"fact": fact, "op": op}
    if value is not None:
        d["value"] = value
    return d


def all_(*conds):
    return {"all": list(conds)}


def any_(*conds):
    return {"any": list(conds)}


def reason(rid, text, tags, aligns, axis=None, value=None):
    r = {"id": rid, "text": text, "tags": tags, "aligns": aligns}
    if axis:
        r["map"] = {"axis": axis, "value": value}
    return r


def trig(tid, prio, kind, question, cond=None, memory=None, exclude_revised=True):
    t = {"id": tid, "priority": prio, "kind": kind, "question": question,
         "condition": cond or {}}
    if memory:
        t["memory"] = {"source": memory, "excludeIfRevised": exclude_revised}
    return t


def tension(qid, text, implication):
    return {"id": qid, "kind": "tension", "text": text, "implication": implication, "answers": []}


def assumption(qid, text, follow_up=None):
    q = {"id": qid, "kind": "assumption", "text": text, "answers": []}
    if follow_up:
        q["followUp"] = follow_up
    return q


def ans(aid, label, nxt=None, next_cond=None, axis=None, value=None):
    a = {"id": aid, "label": label}
    if nxt:
        a["next"] = nxt
    if next_cond:
        a["nextCondition"] = next_cond
    if axis:
        a["map"] = {"axis": axis, "value": value}
    return a


def clarification(qid, text, answers):
    return {"id": qid, "kind": "clarification", "text": text, "answers": answers}


def diff(did, text, distinction, test):
    return {"id": did, "text": text, "distinction": distinction, "test": test}


def voice(vid, descriptor, no_rep, parcial, recon, fuerte):
    return {"id": vid, "descriptor": descriptor,
            "reactions": {"noRepresenta": no_rep, "parcial": parcial,
                          "reconocible": recon, "fuerte": fuerte}}


def side(prefix, values, reasons_, conclusion, responses, generic, caricatures, own, voices):
    """Construye un lado de CRUZA.

    values: 2 textos para S1. reasons_: 2 textos para S2. conclusion: S3.
    responses: dict reasonId -> texto (S4 personalizada). generic: S4 genérica.
    caricatures: 3 tuplas (tipo, texto, explicación). own: pieza del propio lado.
    """
    pieces = []
    for i, t in enumerate(values):
        pieces.append({"id": f"{prefix}_v{i+1}", "text": t, "kind": "valid", "slots": ["S1"]})
    for i, t in enumerate(reasons_):
        pieces.append({"id": f"{prefix}_r{i+1}", "text": t, "kind": "valid", "slots": ["S2"]})
    pieces.append({"id": f"{prefix}_c", "text": conclusion, "kind": "valid", "slots": ["S3"]})
    for i, (rids, t) in enumerate(responses):
        pieces.append({"id": f"{prefix}_resp{i+1}", "text": t, "kind": "valid", "slots": ["S4"],
                       "respondsTo": rids})
    pieces.append({"id": f"{prefix}_respg", "text": generic, "kind": "valid", "slots": ["S4"],
                   "generic": True})
    for i, (ctype, t, crack) in enumerate(caricatures):
        pieces.append({"id": f"{prefix}_k{i+1}", "text": t, "kind": "caricature",
                       "caricatureType": ctype, "crack": crack, "slots": []})
    pieces.append({"id": f"{prefix}_own", "text": own, "kind": "ownSide", "slots": []})
    return {"pieces": pieces, "voices": voices}


AXES = [
    {"id": "ax_intencion_resultado", "left": "Lo que quisiste hacer", "right": "Lo que ocurrió"},
    {"id": "ax_mios_todos", "left": "Los míos", "right": "Todos por igual"},
    {"id": "ax_limites_resultado", "left": "Límites que no cruzo", "right": "El mejor resultado"},
    {"id": "ax_decidir_proteger", "left": "Decidir por mí", "right": "Que me protejan"},
]

PRINCIPLES = [
    ("p_decision", "importa lo que cada uno decide"),
    ("p_resultado", "importa lo que ocurre"),
    ("p_riesgo", "importa el riesgo que se asume"),
    ("p_palabra", "la palabra dada obliga"),
    ("p_mejor_resultado", "buscar el mejor resultado"),
    ("p_cuidado", "cuidar a quien depende de mí"),
    ("p_cercanos", "los cercanos merecen un trato especial"),
    ("p_imparcial", "todos merecen el mismo trato"),
    ("p_verdad", "la verdad no se negocia"),
    ("p_autonomia", "cada quien decide sobre su vida"),
    ("p_proteccion", "proteger puede justificar límites"),
    ("p_mismo_criterio", "el mismo criterio para cada persona"),
    ("p_errores_repartidos", "repartir con justicia los errores"),
    ("p_interior", "comprender requiere algo interior"),
    ("p_conducta", "comprender se ve en lo que se hace"),
    ("p_continuidad_psicologica", "somos nuestra memoria y nuestro carácter"),
    ("p_continuidad_fisica", "somos también un cuerpo"),
    ("p_experiencia_vivida", "hay saberes que solo da la experiencia"),
    ("p_razones_compartibles", "las razones se pueden compartir"),
]

CRUZA_COMMON = {
    "disclosure": "Perspectiva sintetizada a partir de argumentos representativos de esta posición.",
    "simulationNote": "Es una simulación pedagógica basada en perspectivas investigadas. No son testimonios de personas reales.",
    "slots": [
        {"id": "S1", "title": "Lo que les importa", "hint": "El valor que está en juego para ellos.",
         "missing": "Falta lo que más les importa."},
        {"id": "S2", "title": "Por qué aplica aquí", "hint": "El hecho o la razón que conecta ese valor con el caso.",
         "missing": "Falta por qué eso aplica a este caso."},
        {"id": "S3", "title": "Lo que concluyen", "hint": "La postura a la que llegan.",
         "missing": "Falta lo que concluyen."},
        {"id": "S4", "title": "Cómo responden a tu razón", "hint": "Lo que dirían ante tu propia razón.",
         "missing": "Falta cómo responderían a tu razón."},
    ],
    "recognition": {
        "noRepresenta": "No me representa",
        "parcial": "Parcialmente",
        "reconocible": "Sí, así lo diría",
        "fuerte": "Reconstrucción especialmente fuerte",
    },
    "caricatureTypes": {
        "malaIntencion": "Atribuye una mala intención",
        "exageracion": "Exagera la postura hasta un extremo",
        "versionDebil": "Elige la versión más débil",
    },
}

CATALOG_TRAMOS = [
    {"id": 1, "title": "Lo que hacemos"},
    {"id": 2, "title": "Lo que decidimos por otros"},
    {"id": 3, "title": "Quién comprende"},
]
