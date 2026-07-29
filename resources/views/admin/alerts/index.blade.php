@extends('admin.layout')

@section('content')
    <div class="bg-white rounded-lg shadow p-4">
        <div class="flex items-center justify-between gap-4 mb-4">
            <div>
                <h2 class="text-lg font-semibold">Noticias y alertas</h2>
                <p class="text-sm text-gray-600">Estas alertas se muestran en la aplicación móvil.</p>
            </div>
            <a href="{{ route('admin.alerts.create') }}" class="inline-flex items-center px-3 py-2 rounded-md text-sm font-semibold text-white shadow" style="background:#4c8d93;">
                + Nueva alerta
            </a>
        </div>

        <div class="overflow-x-auto">
            <table class="w-full text-sm border border-gray-200">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="text-left px-3 py-2 border-b">Orden</th>
                        <th class="text-left px-3 py-2 border-b">Fuente</th>
                        <th class="text-left px-3 py-2 border-b">Alerta</th>
                        <th class="text-left px-3 py-2 border-b">Estado</th>
                        <th class="text-left px-3 py-2 border-b">Acciones</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($alerts as $alert)
                        <tr class="border-b">
                            <td class="px-3 py-2">{{ $alert->sort_order }}</td>
                            <td class="px-3 py-2 font-semibold">{{ $alert->source }}</td>
                            <td class="px-3 py-2">
                                <p class="font-medium">{{ $alert->title }}</p>
                                <p class="text-xs text-gray-500">{{ $alert->description }}</p>
                            </td>
                            <td class="px-3 py-2">{{ $alert->is_active ? 'Activa' : 'Inactiva' }}</td>
                            <td class="px-3 py-2">
                                <div class="flex gap-2">
                                    <a href="{{ route('admin.alerts.edit', $alert) }}" class="text-blue-700 hover:underline">Editar</a>
                                    <form method="POST" action="{{ route('admin.alerts.destroy', $alert) }}" onsubmit="return confirm('¿Eliminar esta alerta?');">
                                        @csrf
                                        @method('DELETE')
                                        <button class="text-red-700 hover:underline" type="submit">Eliminar</button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr><td colspan="5" class="px-3 py-5 text-center text-gray-500">No hay alertas registradas.</td></tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        <div class="mt-4">{{ $alerts->links() }}</div>
    </div>
@endsection
