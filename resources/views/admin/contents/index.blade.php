@extends('admin.layout')

@section('content')
    @php
        $typeLabels = [
            'articulo' => 'Artículo',
            'video' => 'Video',
            'pdf' => 'PDF',
            'evento' => 'Evento',
        ];
    @endphp

    <div class="bg-white rounded-lg shadow p-4">
        <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold">Contenidos</h2>
            <a
                href="{{ route('admin.contents.create') }}"
                class="inline-flex items-center justify-center px-3 py-2 rounded-md text-sm font-semibold shadow-md border"
                style="min-height:40px;background-color:#4c8d93;color:#ffffff !important;border-color:#3c747a;text-decoration:none;"
            >
                + Nuevo contenido
            </a>
        </div>

        <div class="overflow-x-auto">
            <table class="w-full text-sm border border-gray-200">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="text-left px-3 py-2 border-b">Título</th>
                        <th class="text-left px-3 py-2 border-b">Slug</th>
                        <th class="text-left px-3 py-2 border-b">Tipo</th>
                        <th class="text-left px-3 py-2 border-b">Categoría app</th>
                        <th class="text-left px-3 py-2 border-b">Estado</th>
                        <th class="text-left px-3 py-2 border-b">Destino</th>
                        <th class="text-left px-3 py-2 border-b">Publicado</th>
                        <th class="text-left px-3 py-2 border-b">Acciones</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($contents as $item)
                        @php
                            $payload = json_decode((string) $item->body, true);
                            $category = is_array($payload) ? ($payload['category'] ?? null) : null;
                            $category ??= match ($item->type) {
                                'video' => 'Repositorio en video',
                                'pdf' => 'Artículos Relacionados',
                                'evento' => 'Cronograma Actividades',
                                default => 'Artículos Populares',
                            };
                        @endphp
                        <tr class="border-b">
                            <td class="px-3 py-2">{{ $item->title }}</td>
                            <td class="px-3 py-2">{{ $item->slug }}</td>
                            <td class="px-3 py-2">
                                <span class="inline-flex rounded-full bg-gray-100 px-2 py-1 text-xs font-semibold text-gray-700">
                                    {{ $typeLabels[$item->type] ?? $item->type }}
                                </span>
                            </td>
                            <td class="px-3 py-2">{{ $category }}</td>
                            <td class="px-3 py-2">{{ ucfirst($item->status) }}</td>
                            <td class="px-3 py-2">
                                @if ($item->hasUsableDestination())
                                    <span class="text-green-700 font-medium">Disponible</span>
                                @else
                                    <span class="text-red-700 font-medium">Requiere corrección</span>
                                @endif
                            </td>
                            <td class="px-3 py-2">{{ $item->published_at?->format('Y-m-d H:i') ?? '-' }}</td>
                            <td class="px-3 py-2">
                                <div class="flex gap-2">
                                    <a href="{{ route('admin.contents.edit', $item) }}" class="text-blue-700 hover:underline">Editar</a>
                                    <form method="POST" action="{{ route('admin.contents.destroy', $item) }}" onsubmit="return confirm('¿Eliminar contenido?');">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="bg-red-600 hover:bg-red-700 text-white px-2 py-1 rounded text-xs font-medium shadow-sm transition-colors">Eliminar</button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="8" class="px-3 py-4 text-center text-gray-500">No hay contenidos registrados.</td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div class="mt-4">
            {{ $contents->links() }}
        </div>
    </div>
@endsection
