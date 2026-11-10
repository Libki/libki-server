"use strict";

(() => {
  const form = document.getElementById("upload-form");
  const filesInput = document.getElementById("documents");
  if (!form || !filesInput || typeof DataTransfer === "undefined") return;
  // Keep the original, functional form if the browser cannot build a FileList.
  try { filesInput.files = new DataTransfer().files; } catch (_) { return; }
  const maximum = Number(form.dataset.maxFiles);
  const list = document.getElementById("selected-files");
  const feedback = document.getElementById("file-feedback");
  const addButton = document.getElementById("add-file");
  const picker = document.createElement("input");
  picker.type = "file";
  picker.multiple = true;
  picker.accept = filesInput.accept;
  picker.hidden = true;
  picker.id = "add-file-picker";
  form.appendChild(picker);
  document.getElementById("legacy-documents").hidden = true;
  document.getElementById("legacy-copies").hidden = true;
  document.querySelector("[name=copies]").disabled = true;
  filesInput.required = false;
  document.getElementById("file-selection").hidden = false;
  let selected = [];
  let nextId = 0;

  function render() {
    const transfer = new DataTransfer();
    list.replaceChildren();
    for (const item of selected) {
      transfer.items.add(item.file);
      const row = document.createElement("li");
      row.className = "selected-file";
      const info = document.createElement("div");
      info.className = "file-info";
      const name = document.createElement("strong");
      name.textContent = item.file.name;
      const size = document.createElement("span");
      size.textContent = `${(item.file.size / 1024 / 1024).toFixed(2)} MB`;
      info.append(name, size);
      const label = document.createElement("label");
      label.textContent = "Copies";
      const quantity = document.createElement("input");
      quantity.type = "number";
      quantity.name = "file_copies";
      quantity.min = "1";
      quantity.max = "99";
      quantity.step = "1";
      quantity.required = true;
      quantity.inputMode = "numeric";
      quantity.value = item.copies;
      quantity.setAttribute("aria-label", `Copies for ${item.file.name}`);
      quantity.addEventListener("input", () => { item.copies = quantity.value; });
      label.appendChild(quantity);
      const remove = document.createElement("button");
      remove.type = "button";
      remove.className = "remove-file";
      remove.textContent = "Remove";
      remove.setAttribute("aria-label", `Remove ${item.file.name}`);
      remove.addEventListener("click", () => {
        selected = selected.filter(entry => entry.id !== item.id);
        render();
        feedback.textContent = `${item.file.name} removed. ${selected.length} of ${maximum} files selected.`;
        addButton.focus();
      });
      row.append(info, label, remove);
      list.appendChild(row);
    }
    filesInput.files = transfer.files;
    document.getElementById("file-count").textContent = `${selected.length} of ${maximum}`;
    addButton.textContent = selected.length ? "Add another file" : "Choose a file";
    addButton.disabled = selected.length >= maximum;
  }

  addButton.addEventListener("click", () => picker.click());
  picker.addEventListener("change", () => {
    const incoming = Array.from(picker.files);
    picker.value = ""; // Re-selecting a removed file must trigger change again.
    if (!incoming.length) return;
    if (selected.length + incoming.length > maximum) {
      feedback.textContent = `You can upload up to ${maximum} files. Your existing files are unchanged. Choose fewer files or remove one first.`;
      return;
    }
    const unsupported = incoming.some(file => !/\.(pdf|docx|odt|txt|jpe?g|png)$/i.test(file.name));
    if (unsupported || incoming.some(file => !file.size || file.size > 20 * 1024 * 1024)) {
      feedback.textContent = "Choose a supported, nonempty file no larger than 20 MB. Your existing files are unchanged.";
      return;
    }
    const total = [...selected.map(item => item.file), ...incoming].reduce((sum, file) => sum + file.size, 0);
    if (total > 90 * 1024 * 1024) {
      feedback.textContent = "The combined files must be no larger than 90 MB. Your existing files are unchanged.";
      return;
    }
    for (const file of incoming) selected.push({id: ++nextId, file, copies: "1"});
    render();
    feedback.textContent = `${selected.length} of ${maximum} files selected. ${selected.length === maximum ? "All five slots are filled. Remove a file to replace it." : "You can add another file."}`;
  });
  form.addEventListener("submit", event => {
    if (!selected.length) {
      event.preventDefault();
      feedback.textContent = "Choose at least one document before uploading.";
      addButton.focus();
    }
  });
  form.addEventListener("reset", () => {
    selected = [];
    render();
    feedback.textContent = "No files selected yet.";
  });
  render();
})();
