/* IPFire captive logo preview. GPL-3.0-or-later. */
(() => {
  'use strict';
  const input = document.getElementById('captive-logo-input');
  if (!input) return;
  const box = document.getElementById('captive-logo-preview');
  const image = document.getElementById('captive-logo-image');
  const caption = document.getElementById('captive-logo-caption');
  const error = document.getElementById('captive-logo-error');
  const clear = document.getElementById('captive-logo-clear');
  const filename = document.getElementById('captive-logo-filename');
  let revision = 0;
  const current = () => {
    caption.textContent = caption.dataset.current;
    image.alt = caption.dataset.current;
    if (image.dataset.currentSrc) {
      image.src = image.dataset.currentSrc;
      box.style.display = '';
    } else {
      image.removeAttribute('src');
      box.style.display = 'none';
    }
  };
  const invalid = message => {
    input.setCustomValidity(message);
    error.textContent = message;
    current();
  };
  clear.addEventListener('click', () => {
    revision++;
    input.value = '';
    input.setCustomValidity('');
    error.textContent = '';
    filename.textContent = filename.dataset.empty;
    clear.hidden = true;
    current();
  });
  input.addEventListener('change', () => {
    const selected = ++revision;
    const file = input.files && input.files[0];
    filename.textContent = file ? file.name : filename.dataset.empty;
    input.setCustomValidity('');
    error.textContent = '';
    clear.hidden = !file;
    if (!file) { current(); return; }
    if (file.size > Number(input.dataset.maxBytes)) {
      invalid(input.dataset.tooLarge);
      return;
    }
    if (file.type && !['image/png', 'image/jpeg'].includes(file.type)) {
      invalid(input.dataset.invalidType);
      return;
    }
    const reader = new FileReader();
    reader.onerror = () => {
      if (selected === revision) invalid(input.dataset.previewError);
    };
    reader.onload = () => {
      if (selected !== revision) return;
      const candidate = new Image();
      candidate.onerror = () => {
        if (selected === revision) invalid(input.dataset.previewError);
      };
      candidate.onload = () => {
        if (selected !== revision) return;
        image.src = reader.result;
        image.alt = caption.dataset.selected;
        caption.textContent = caption.dataset.selected;
        box.style.display = '';
      };
      candidate.src = reader.result;
    };
    reader.readAsDataURL(file);
  });
})();
