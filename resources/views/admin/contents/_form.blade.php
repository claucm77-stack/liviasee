@php
    $selectedType = old('type', $content->type ?? 'articulo');
    $payloadData = $bodyData['data'] ?? [];
    $selectedCategoryId = old('content_category_id', $content->content_category_id ?? '');
    $imageUrl = old('image_url', $bodyData['image_url'] ?? '');
    $inputClass = 'w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-[#4c8d93] focus:border-[#4c8d93]';
    $sectionClass = 'rounded-lg border border-gray-200 bg-gray-50 p-4 space-y-4';
@endphp

@if ($errors->any())
    <div class="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
        <p class="font-semibold">Revisa la información del formulario:</p>
        <ul class="mt-2 list-disc pl-5">
            @foreach ($errors->all() as $error)
                <li>{{ $error }}</li>
            @endforeach
        </ul>
    </div>
@endif

<div class="grid gap-4 md:grid-cols-2">
    <div>
        <label class="block text-sm font-medium mb-1">Título</label>
        <input type="text" name="title" value="{{ old('title', $content->title ?? '') }}" class="{{ $inputClass }}" required>
    </div>

    <div>
        <label class="block text-sm font-medium mb-1">Slug (opcional)</label>
        <input type="text" name="slug" value="{{ old('slug', $content->slug ?? '') }}" class="{{ $inputClass }}" placeholder="se-genera-automaticamente">
    </div>
</div>

<div class="grid gap-4 md:grid-cols-2">
    <div>
        <label class="block text-sm font-medium mb-1">Tipo de contenido</label>
        <select
            id="content-type"
            name="type"
            class="{{ $inputClass }}"
            required
        >
            @foreach ($contentTypes as $value => $label)
                <option value="{{ $value }}" @selected($selectedType === $value)>{{ $label }}</option>
            @endforeach
        </select>
        <p class="mt-1 text-xs text-gray-500">Al cambiar el tipo, el formulario muestra solo los campos necesarios.</p>
    </div>

    <div>
        <label class="block text-sm font-medium mb-1">Estado</label>
        <select name="status" class="{{ $inputClass }}" required>
            @foreach (['borrador' => 'Borrador', 'publicado' => 'Publicado', 'archivado' => 'Archivado'] as $value => $label)
                <option value="{{ $value }}" @selected(old('status', $content->status ?? 'borrador') === $value)>{{ $label }}</option>
            @endforeach
        </select>
    </div>
</div>

<div>
    <label class="block text-sm font-medium mb-1">Categoría visible en la app</label>
    <select name="content_category_id" class="{{ $inputClass }}" required>
        <option value="">Selecciona una categoría</option>
        @foreach ($contentCategories as $category)
            <option value="{{ $category->id }}" @selected((string) $selectedCategoryId === (string) $category->id)>{{ $category->name }}</option>
        @endforeach
    </select>
    <p class="mt-1 text-xs text-gray-500">La app usará esta categoría para filtrar el contenido cuando el usuario toque su tarjeta de inicio.</p>
</div>

<div>
    <label class="block text-sm font-medium mb-1">Resumen para tarjetas y listados</label>
    <textarea name="summary" rows="3" class="{{ $inputClass }}" placeholder="Describe brevemente qué encontrará el usuario.">{{ old('summary', $content->summary ?? '') }}</textarea>
</div>

<div class="grid gap-4 md:grid-cols-2">
    <div>
        <label class="block text-sm font-medium mb-1">Imagen de portada (URL)</label>
        <input type="url" name="image_url" value="{{ $imageUrl }}" class="{{ $inputClass }}" placeholder="https://...">
    </div>

    <div>
        <label class="block text-sm font-medium mb-1">Fecha de publicación (opcional)</label>
        <input
            type="datetime-local"
            name="published_at"
            value="{{ old('published_at', isset($content) && $content->published_at ? $content->published_at->format('Y-m-d\TH:i') : '') }}"
            class="{{ $inputClass }}"
        >
    </div>
</div>

<section data-content-section="articulo" class="{{ $sectionClass }}">
    <div>
        <h3 class="text-base font-semibold text-gray-900">Información del artículo</h3>
        <p class="text-sm text-gray-600">Usa este tipo para lecturas, guías, noticias o material escrito.</p>
    </div>

    <div class="grid gap-4 md:grid-cols-2">
        <div>
            <label class="block text-sm font-medium mb-1">Autor o responsable</label>
            <input type="text" name="author_name" value="{{ old('author_name', $payloadData['author_name'] ?? '') }}" class="{{ $inputClass }}" placeholder="Nombre del autor">
        </div>
        <div>
            <label class="block text-sm font-medium mb-1">Tiempo de lectura (minutos)</label>
            <input type="number" min="1" name="reading_time" value="{{ old('reading_time', $payloadData['reading_time'] ?? '') }}" class="{{ $inputClass }}">
        </div>
    </div>

    <div>
        <label class="block text-sm font-medium mb-1">Texto del artículo</label>
        <textarea name="article_body" rows="10" class="{{ $inputClass }}" placeholder="Escribe el contenido completo del artículo.">{{ old('article_body', $payloadData['body'] ?? '') }}</textarea>
    </div>
</section>

<section data-content-section="video" class="{{ $sectionClass }}">
    <div>
        <h3 class="text-base font-semibold text-gray-900">Información del video</h3>
        <p class="text-sm text-gray-600">Usa este tipo para videos alojados en YouTube, Vimeo, Drive u otra URL pública.</p>
    </div>

    <div class="grid gap-4 md:grid-cols-2">
        <div>
            <label class="block text-sm font-medium mb-1">URL del video</label>
            <input type="url" name="video_url" value="{{ old('video_url', $payloadData['video_url'] ?? '') }}" class="{{ $inputClass }}" placeholder="https://...">
        </div>
        <div>
            <label class="block text-sm font-medium mb-1">Duración</label>
            <input type="text" name="video_duration" value="{{ old('video_duration', $payloadData['duration'] ?? '') }}" class="{{ $inputClass }}" placeholder="Ej. 12:35">
        </div>
    </div>

    <div>
        <label class="block text-sm font-medium mb-1">Transcripción o notas del video</label>
        <textarea name="transcript" rows="7" class="{{ $inputClass }}" placeholder="Resumen ampliado, capítulos o transcripción.">{{ old('transcript', $payloadData['transcript'] ?? '') }}</textarea>
    </div>
</section>

<section data-content-section="pdf" class="{{ $sectionClass }}">
    <div>
        <h3 class="text-base font-semibold text-gray-900">Información del PDF</h3>
        <p class="text-sm text-gray-600">Usa este tipo para documentos, cartillas, formatos descargables o presentaciones.</p>
    </div>

    <div class="grid gap-4 md:grid-cols-2">
        <div>
            <label class="block text-sm font-medium mb-1">URL del PDF</label>
            <input type="url" name="pdf_url" value="{{ old('pdf_url', $payloadData['pdf_url'] ?? '') }}" class="{{ $inputClass }}" placeholder="https://...pdf">
        </div>
        <div>
            <label class="block text-sm font-medium mb-1">Número de páginas</label>
            <input type="number" min="1" name="pages" value="{{ old('pages', $payloadData['pages'] ?? '') }}" class="{{ $inputClass }}">
        </div>
    </div>

    <div>
        <label class="block text-sm font-medium mb-1">Indicaciones para el documento</label>
        <textarea name="document_instructions" rows="6" class="{{ $inputClass }}" placeholder="Qué debe leer, descargar o completar el usuario.">{{ old('document_instructions', $payloadData['instructions'] ?? '') }}</textarea>
    </div>
</section>

<section data-content-section="evento" class="{{ $sectionClass }}">
    <div>
        <h3 class="text-base font-semibold text-gray-900">Información del evento</h3>
        <p class="text-sm text-gray-600">Usa este tipo para actividades del cronograma, talleres, conferencias o encuentros.</p>
    </div>

    <div class="grid gap-4 md:grid-cols-2">
        <div>
            <label class="block text-sm font-medium mb-1">Inicio del evento</label>
            <input type="datetime-local" name="event_starts_at" value="{{ old('event_starts_at', isset($payloadData['starts_at']) ? str_replace(' ', 'T', substr($payloadData['starts_at'], 0, 16)) : '') }}" class="{{ $inputClass }}">
        </div>
        <div>
            <label class="block text-sm font-medium mb-1">Fin del evento</label>
            <input type="datetime-local" name="event_ends_at" value="{{ old('event_ends_at', isset($payloadData['ends_at']) ? str_replace(' ', 'T', substr((string) $payloadData['ends_at'], 0, 16)) : '') }}" class="{{ $inputClass }}">
        </div>
    </div>

    <div class="grid gap-4 md:grid-cols-2">
        <div>
            <label class="block text-sm font-medium mb-1">Modalidad</label>
            <select name="event_modality" class="{{ $inputClass }}">
                @foreach (['presencial' => 'Presencial', 'virtual' => 'Virtual', 'hibrido' => 'Híbrido'] as $value => $label)
                    <option value="{{ $value }}" @selected(old('event_modality', $payloadData['modality'] ?? 'presencial') === $value)>{{ $label }}</option>
                @endforeach
            </select>
        </div>
        <div>
            <label class="block text-sm font-medium mb-1">Lugar o enlace de encuentro</label>
            <input type="text" name="event_location" value="{{ old('event_location', $payloadData['location'] ?? '') }}" class="{{ $inputClass }}" placeholder="Auditorio, salón, Meet, Zoom...">
        </div>
    </div>

    <div>
        <label class="block text-sm font-medium mb-1">URL de inscripción (opcional)</label>
        <input type="url" name="registration_url" value="{{ old('registration_url', $payloadData['registration_url'] ?? '') }}" class="{{ $inputClass }}" placeholder="https://...">
    </div>

    <div>
        <label class="block text-sm font-medium mb-1">Agenda o descripción del evento</label>
        <textarea name="event_agenda" rows="7" class="{{ $inputClass }}" placeholder="Objetivo, público, agenda y requisitos.">{{ old('event_agenda', $payloadData['agenda'] ?? '') }}</textarea>
    </div>
</section>

<div class="flex flex-wrap gap-2 pt-2">
    <button type="submit" class="bg-blue-700 hover:bg-blue-800 text-white px-4 py-2 rounded-md text-sm font-medium">
        {{ $submitLabel }}
    </button>
    <a href="{{ route('admin.contents.index') }}" class="px-4 py-2 rounded-md text-sm border">Cancelar</a>
</div>

<script>
    document.addEventListener('DOMContentLoaded', () => {
        const select = document.getElementById('content-type');
        const sections = Array.from(document.querySelectorAll('[data-content-section]'));

        const syncSections = () => {
            const selected = select.value;
            sections.forEach((section) => {
                section.classList.toggle('hidden', section.dataset.contentSection !== selected);
            });
        };

        select.addEventListener('change', () => {
            syncSections();
        });
        syncSections();
    });
</script>
