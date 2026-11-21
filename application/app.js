// Block 5: Auth login, role views, search box.
// Uses only the publishable key, so RLS decides what each user sees and edits.
const SUPABASE_URL = "https://yiciamzjofmmwunslkvc.supabase.co";
const SUPABASE_KEY = "sb_publishable_535OBAd_z1198FlsocgZWg_yn8mNmwN";
const sb = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

const $ = id => document.getElementById(id);
let view = "marks";
let rows = [];

// ---------- small helpers (DOM only, never innerHTML, so no XSS) ----------
function el(tag, text, attrs) {
  const n = document.createElement(tag);
  if (text !== undefined && text !== null) n.textContent = text;
  Object.assign(n, attrs || {});
  return n;
}
function msg(text, type) {
  const m = $("msg");
  m.className = type;
  m.textContent = text;
  m.hidden = false;
  m.style.display = "block";
}
function table(headers, body) {
  const t = el("table");
  const hr = el("tr");
  headers.forEach(h => hr.appendChild(el("th", h)));
  t.appendChild(hr);
  body.forEach(cells => {
    const tr = el("tr");
    cells.forEach(c => {
      const td = el("td");
      td.appendChild(typeof c === "object" && c !== null && c.nodeType ? c : document.createTextNode(c ?? ""));
      tr.appendChild(td);
    });
    t.appendChild(tr);
  });
  return t;
}

// ---------- auth ----------
$("login").addEventListener("submit", async e => {
  e.preventDefault();
  const { data, error } = await sb.auth.signInWithPassword({ email: $("email").value, password: $("pw").value });
  if (error) return alert("Login failed: " + error.message);
  $("pw").value = "";
  start(data.user);
});
$("logout").addEventListener("click", async () => { await sb.auth.signOut(); location.reload(); });

async function start(user) {
  $("login").hidden = true;
  $("app").hidden = false;
  $("who").textContent = user.email;
  // RLS lets a user read only their own profile row (admin reads all).
  const { data } = await sb.from("profiles").select("app_role").eq("id", user.id).maybeSingle();
  $("role").textContent = data?.app_role ?? "unknown";
  show("marks");
}

// ---------- tabs ----------
$("t-marks").addEventListener("click", () => show("marks"));
$("t-audit").addEventListener("click", () => show("audit"));
$("search").addEventListener("input", render);

function show(v) {
  view = v;
  $("t-marks").className = v === "marks" ? "on" : "";
  $("t-audit").className = v === "audit" ? "on" : "";
  $("search").value = "";
  $("msg").style.display = "none";
  load();
}

// ---------- data ----------
async function load() {
  let q;
  if (view === "marks") {
    q = sb.from("enrollments")
      .select("id, marks, grade, updated_at, students(student_number, full_name), courses(course_code, title)")
      .order("id");
  } else {
    q = sb.from("audit_logs").select("*").order("changed_at", { ascending: false }).limit(50);
  }
  const { data, error } = await q;
  if (error) {
    rows = [];
    $("count").textContent = "";
    $("out").replaceChildren();
    return msg("Could not read data: " + error.message, "bad");
  }
  rows = data;
  render();
}

function render() {
  const term = $("search").value.trim().toLowerCase();
  // Search runs in the browser on rows RLS already allowed, so it can never reveal more.
  const shown = rows.filter(r => !term || JSON.stringify(r).toLowerCase().includes(term));
  $("count").textContent = `${shown.length} of ${rows.length} row(s) visible to you`;
  if (!rows.length) {
    $("out").replaceChildren(el("p", view === "audit"
      ? "No audit rows visible. Only administrators can read audit_logs."
      : "No rows visible to this account."));
    return;
  }
  $("out").replaceChildren(view === "marks" ? marksTable(shown) : auditTable(shown));
}

function marksTable(list) {
  return table(
    ["Student no.", "Student", "Course", "Marks", "Grade", "Edit marks"],
    list.map(r => {
      const input = el("input", null, { type: "number", min: 0, max: 100, step: "0.01", value: r.marks ?? "" });
      const btn = el("button", "Save", { type: "button" });
      btn.addEventListener("click", () => saveMarks(r.id, input.value));
      const box = el("span");
      box.append(input, btn);
      return [
        r.students?.student_number, r.students?.full_name,
        `${r.courses?.course_code ?? ""} ${r.courses?.title ?? ""}`,
        r.marks, r.grade, box
      ];
    })
  );
}

function auditTable(list) {
  const short = o => (o ? JSON.stringify(o).slice(0, 80) : "");
  return table(
    ["When", "Table", "Operation", "Record", "DB role", "Old", "New"],
    list.map(r => [new Date(r.changed_at).toLocaleString(), r.table_name, r.operation,
      r.record_id, r.changed_by_db_role, short(r.old_data), short(r.new_data)])
  );
}

// ---------- update marks (the grade is set by the database trigger) ----------
async function saveMarks(id, value) {
  const marks = Number(value);
  if (value === "" || Number.isNaN(marks) || marks < 0 || marks > 100) {
    return msg("Enter marks between 0 and 100.", "info");
  }
  const { data, error } = await sb.from("enrollments").update({ marks }).eq("id", id).select("id, marks, grade");
  if (error) {
    msg(`Blocked by the database (${error.code || "error"}): ${error.message}`, "bad");
  } else if (!data.length) {
    msg("Blocked by RLS: 0 rows changed. Your role may not edit this record.", "bad");
  } else {
    msg(`Saved. The trigger set the grade to ${data[0].grade} for marks ${data[0].marks}.`, "ok");
  }
  load();
}

// Keep the user signed in after a page refresh.
sb.auth.getSession().then(({ data }) => { if (data.session) start(data.session.user); });
