@extends('admin.layout')

@section('content')
    <div class="bg-white rounded-lg shadow p-4">
        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-3 mb-4">
            <h2 class="text-lg font-semibold">Gestión de usuarios</h2>

            <div class="flex gap-2 items-center flex-wrap">
                <form method="GET" action="{{ route('admin.users.index') }}" class="flex gap-2">
                    <input
                        type="text"
                        name="search"
                        value="{{ $search }}"
                        placeholder="Buscar por nombre o email"
                        class="border rounded-md px-3 py-2 text-sm w-60"
                    >
                    <button type="submit" class="bg-gray-800 hover:bg-gray-900 text-white px-3 py-2 rounded-md text-sm font-medium shadow-sm transition-colors">Buscar</button>
                </form>

                <a
                    href="{{ route('admin.users.create') }}"
                    class="inline-flex items-center justify-center px-3 py-2 rounded-md text-sm font-semibold whitespace-nowrap shadow-md border"
                    style="min-height:40px;background-color:#4c8d93;color:#ffffff !important;border-color:#3c747a;text-decoration:none;"
                >
                    + Nuevo usuario
                </a>
            </div>
        </div>

        <div class="overflow-x-auto">
            <table class="w-full text-sm border border-gray-200">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="text-left px-3 py-2 border-b">Nombre</th>
                        <th class="text-left px-3 py-2 border-b">Email</th>
                        <th class="text-left px-3 py-2 border-b">Rol</th>
                        <th class="text-left px-3 py-2 border-b">Estado</th>
                        <th class="text-left px-3 py-2 border-b">Acceso app</th>
                        <th class="text-left px-3 py-2 border-b">Acciones</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($users as $user)
                        @php
                            $userIdentifier = (string) (
                                $user['uid']
                                ?? $user['firebase_uid']
                                ?? $user['id']
                                ?? ''
                            );
                        @endphp
                        <tr class="border-b">
                            <td class="px-3 py-2">{{ $user['name'] ?? '' }}</td>
                            <td class="px-3 py-2">{{ $user['email'] ?? '' }}</td>
                            <td class="px-3 py-2">
                                {{ \App\Constants\Roles::getDisplayName((string) ($user['role'] ?? \App\Constants\Roles::DEFAULT)) }}
                            </td>
                            <td class="px-3 py-2">
                                @if (($user['is_active'] ?? false))
                                    <span class="text-green-700 font-medium">Activo</span>
                                @else
                                    <span class="text-red-700 font-medium">Inactivo</span>
                                @endif
                            </td>
                            <td class="px-3 py-2">
                                @if (($user['app_linked'] ?? false))
                                    <span class="text-green-700 font-medium">Vinculado</span>
                                @else
                                    <span class="text-amber-700 font-medium">Pendiente de vincular</span>
                                @endif
                            </td>
                            <td class="px-3 py-2">
                                <div class="flex gap-2">
                                    <a href="{{ route('admin.users.edit', $userIdentifier) }}" class="text-blue-700 hover:underline">Editar</a>

                                    @if ((string) (auth()->user()?->firebase_uid ?? '') !== $userIdentifier)
                                        <form method="POST" action="{{ route('admin.users.destroy', $userIdentifier) }}" onsubmit="return confirm('¿Eliminar usuario?');">
                                            @csrf
                                            @method('DELETE')
                                            <button type="submit" class="bg-red-600 hover:bg-red-700 text-white px-2 py-1 rounded text-xs font-medium shadow-sm transition-colors">Eliminar</button>
                                        </form>
                                    @endif
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="px-3 py-4 text-center text-gray-500">No hay usuarios registrados en Laravel.</td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div class="mt-4">
            {{ $users->links() }}
        </div>
    </div>
@endsection
