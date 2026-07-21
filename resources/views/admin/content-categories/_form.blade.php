@php
    $inputClass = 'w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-[#4c8d93] focus:border-[#4c8d93]';
@endphp

<div class="grid gap-4 md:grid-cols-2">
    <div>
        <label class="block text-sm font-medium mb-1">Nombre</label>
        <input name="name" value="{{ old('name', $contentCategory->name ?? '') }}" class="{{ $inputClass }}" required>
        <p class="mt-1 text-xs text-gray-500">Este nombre es el filtro que verá la app móvil.</p>
    </div>
    <div>
        <label class="block text-sm font-medium mb-1">Orden</label>
        <input type="number" min="0" name="sort_order" value="{{ old('sort_order', $contentCategory->sort_order ?? 0) }}" class="{{ $inputClass }}">
    </div>
</div>

<div>
    <label class="block text-sm font-medium mb-1">Descripción</label>
    <textarea name="description" rows="3" class="{{ $inputClass }}" placeholder="Texto mostrado bajo la categoría en la app.">{{ old('description', $contentCategory->description ?? '') }}</textarea>
</div>

<div>
    <label class="block text-sm font-medium mb-1">Imagen de la categoría</label>
    <input type="file" name="image" accept="image/*" class="{{ $inputClass }}" @if (!isset($contentCategory)) required @endif>
    @if (isset($contentCategory) && ($contentCategory->image_path || $contentCategory->image_url))
        <img src="{{ $contentCategory->imageUrl() }}" alt="Imagen actual" class="mt-2 h-20 w-36 rounded object-cover">
    @endif
</div>

<label class="inline-flex items-center gap-2 text-sm font-semibold">
    <input type="checkbox" name="is_active" value="1" @checked(old('is_active', $contentCategory->is_active ?? true))>
    Visible en la app móvil
</label>

<div class="flex flex-wrap gap-2 pt-2">
    <button type="submit" class="bg-blue-700 hover:bg-blue-800 text-white px-4 py-2 rounded-md text-sm font-medium">{{ $submitLabel }}</button>
    <a href="{{ route('admin.content-categories.index') }}" class="px-4 py-2 rounded-md text-sm border">Cancelar</a>
</div>
