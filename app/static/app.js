const API_BASE = "/notes";

const form = document.getElementById("note-form");
const idField = document.getElementById("note-id");
const titleField = document.getElementById("note-title");
const contentField = document.getElementById("note-content");
const submitBtn = document.getElementById("submit-btn");
const cancelBtn = document.getElementById("cancel-btn");
const formTitle = document.getElementById("form-title");
const grid = document.getElementById("items-grid");
const emptyState = document.getElementById("empty-state");
const statTotal = document.getElementById("stat-total");

function escapeHtml(value) {
  const div = document.createElement("div");
  div.textContent = value ?? "";
  return div.innerHTML;
}

async function loadNotes() {
  const response = await fetch(API_BASE);
  const notes = await response.json();
  renderNotes(notes);
}

function renderNotes(notes) {
  statTotal.textContent = notes.length;
  emptyState.style.display = notes.length === 0 ? "block" : "none";

  grid.innerHTML = notes
    .map(
      (note) => `
        <div class="item-card">
          <h3>${escapeHtml(note.title)}</h3>
          <p>${escapeHtml(note.content || "")}</p>
          <div class="meta"><span>${escapeHtml(note.created_at)}</span></div>
          <div class="actions">
            <button class="ghost" data-edit="${note.id}">Edit</button>
            <button class="danger" data-delete="${note.id}">Delete</button>
          </div>
        </div>
      `
    )
    .join("");

  grid.querySelectorAll("[data-edit]").forEach((button) => {
    const note = notes.find((n) => n.id === Number(button.dataset.edit));
    button.addEventListener("click", () => startEdit(note));
  });
  grid.querySelectorAll("[data-delete]").forEach((button) => {
    button.addEventListener("click", () => deleteNote(Number(button.dataset.delete)));
  });
}

function startEdit(note) {
  idField.value = note.id;
  titleField.value = note.title;
  contentField.value = note.content;
  formTitle.textContent = "Edit note";
  submitBtn.textContent = "Save changes";
  cancelBtn.style.display = "inline-block";
  titleField.focus();
}

function resetForm() {
  form.reset();
  idField.value = "";
  formTitle.textContent = "New note";
  submitBtn.textContent = "Add note";
  cancelBtn.style.display = "none";
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const payload = { title: titleField.value, content: contentField.value };
  const id = idField.value;

  if (id) {
    await fetch(`${API_BASE}/${id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
  } else {
    await fetch(API_BASE, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
  }

  resetForm();
  loadNotes();
});

cancelBtn.addEventListener("click", resetForm);

async function deleteNote(id) {
  if (!confirm("Delete this note?")) return;
  await fetch(`${API_BASE}/${id}`, { method: "DELETE" });
  loadNotes();
}

loadNotes();
