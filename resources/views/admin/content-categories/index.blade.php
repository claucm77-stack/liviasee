@extends('admin.layout')

@section('content')
    <div class="rounded-lg bg-white p-6 shadow">
        <div class="flex items-center justify-between gap-4">
            <div>
                <h2 class="text-lg font-semibold">Categorías de contenidos</h2>
                <p class="text-sm text-gray-600">Las categorías activas aparecen como tarjetas en la app móvil.</p>
            </div>
            <a href="{{ route('admin.content-categories.create') }}" class="rounded bg-blue-700 px-4 py-2 text-sm font-medium text-white">+ Nueva categoría</a>
        </div>
        <div class="mt-5 overflow-x-auto">
            <table class="min-w-full text-sm">
                <thead><tr class="border-b text-left"><th class="p-2">Imagen</th><th class="p-2">Nombre</th><th class="p-2">Orden</th><th class="p-2">Estado</th><th class="p-2"></th></tr></thead>
                <tbody>
                    @forelse ($categories as $category)
                        <tr class="border-b"><td class="p-2">@if($category->image_path || $category->image_url)<img src="{{ $category->imageUrl() }}" alt="" class="h-10 w-16 rounded object-cover">@endif</td><td class="p-2 font-medium">{{ $category->name }}</td><td class="p-2">{{ $category->sort_order }}</td><td class="p-2">{{ $category->is_active ? 'Activa' : 'Oculta' }}</td><td class="p-2 whitespace-nowrap"><a href="{{ route('admin.content-categories.edit', $category) }}" class="text-blue-700 hover:underline">Editar</a><form method="POST" action="{{ route('admin.content-categories.destroy', $category) }}" class="inline" onsubmit="return confirm('¿Eliminar categoría?')">@csrf @method('DELETE')<button class="ml-3 text-red-700 hover:underline">Eliminar</button></form></td></tr>
                    @empty
                        <tr><td colspan="5" class="p-4 text-center text-gray-500">No hay categorías. Crea la primera para mostrarla en la app.</td></tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        <div class="mt-4">{{ $categories->links() }}</div>
    </div>
@endsection
