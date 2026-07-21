import './bootstrap';

import Alpine from 'alpinejs';

window.Alpine = Alpine;

Alpine.start();

const passwordIcon = (visible) => visible
    ? `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 3l18 18M10.6 10.7a2 2 0 0 0 2.7 2.7M9.9 4.2A10.7 10.7 0 0 1 12 4c5.5 0 9 5.2 9 5.2a15.8 15.8 0 0 1-2.1 2.6M6.6 6.6C4.4 8 3 10.2 3 10.2S6.5 16 12 16a9.8 9.8 0 0 0 3.4-.6"/></svg>`
    : `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 12s3.5-6 9-6 9 6 9 6-3.5 6-9 6-9-6-9-6Z"/><circle cx="12" cy="12" r="2.5"/></svg>`;

function enhancePasswordInputs(root = document) {
    root.querySelectorAll('input[type="password"]').forEach((input) => {
        if (input.dataset.passwordToggleReady === 'true') return;
        input.dataset.passwordToggleReady = 'true';

        const wrapper = document.createElement('div');
        wrapper.className = 'password-field';
        input.parentNode.insertBefore(wrapper, input);
        wrapper.appendChild(input);

        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'password-toggle';
        button.setAttribute('aria-label', 'Mostrar contraseña');
        button.setAttribute('aria-pressed', 'false');
        button.title = 'Mostrar contraseña';
        button.innerHTML = passwordIcon(false);

        button.addEventListener('click', () => {
            const isVisible = input.type === 'text';
            input.type = isVisible ? 'password' : 'text';
            const label = isVisible ? 'Mostrar contraseña' : 'Ocultar contraseña';
            button.setAttribute('aria-label', label);
            button.setAttribute('aria-pressed', String(!isVisible));
            button.title = label;
            button.innerHTML = passwordIcon(!isVisible);
            input.focus({ preventScroll: true });
        });

        wrapper.appendChild(button);
    });
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => enhancePasswordInputs());
} else {
    enhancePasswordInputs();
}
