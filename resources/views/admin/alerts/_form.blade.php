@php
    $inputClass = 'w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-[#4c8d93]';
@endphp

<div>
    <label class="block text-sm font-medium mb-1">Fuente o entidad</label>
    <input class="{{ $inputClass }}" name="source" required maxlength="160" value="{{ old('source', $alert->source ?? '') }}" placeholder="DIAN, Cámara de Comercio...">
</div>
<div>
    <label class="block text-sm font-medium mb-1">Título</label>
    <input class="{{ $inputClass }}" name="title" required maxlength="255" value="{{ old('title', $alert->title ?? '') }}">
</div>
<div>
    <label class="block text-sm font-medium mb-1">Descripción</label>
    <textarea class="{{ $inputClass }}" name="description" rows="5" maxlength="2000">{{ old('description', $alert->description ?? '') }}</textarea>
</div>
<div>
    <label class="block text-sm font-medium mb-1">Enlace externo (opcional)</label>
    <input class="{{ $inputClass }}" type="url" name="link_url" value="{{ old('link_url', $alert->link_url ?? '') }}" placeholder="https://...">
</div>
<div class="grid gap-4 md:grid-cols-2">
    <div>
        <label class="block text-sm font-medium mb-1">Orden</label>
        <input class="{{ $inputClass }}" type="number" min="0" name="sort_order" value="{{ old('sort_order', $alert->sort_order ?? 0) }}">
    </div>
    <label class="flex items-center gap-2 pt-7">
        <input type="checkbox" name="is_active" value="1" @checked(old('is_active', $alert->is_active ?? true))>
        <span class="text-sm font-medium">Visible en la app</span>
    </label>
</div>
<div class="flex gap-2 pt-2">
    <button type="submit" class="px-4 py-2 rounded-md text-white font-semibold" style="background:#4c8d93;">{{ $submitLabel }}</button>
    <a href="{{ route('admin.alerts.index') }}" class="px-4 py-2 rounded-md border">Cancelar</a>
</div>
