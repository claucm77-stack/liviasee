@extends('admin.layout')

@section('content')
    <div class="bg-white rounded-lg shadow p-4 max-w-2xl">
        <h2 class="text-lg font-semibold mb-4">
            {{ $isEdit ? 'Editar usuario' : 'Crear usuario' }}
        </h2>

        <form
            method="POST"
            action="{{ $isEdit ? route('admin.users.update', ['user' => data_get($user, 'uid')]) : route('admin.users.store') }}"
            class="space-y-4"
        >
            @csrf
            @if ($isEdit)
                @method('PUT')
            @endif

            <div>
                <label class="block text-sm font-medium mb-1">Nombre</label>
                <input
                    type="text"
                    name="name"
                    value="{{ old('name', data_get($user, 'name')) }}"
                    class="border rounded-md px-3 py-2 w-full"
                    required
                >
            </div>

            <div>
                <label class="block text-sm font-medium mb-1">Email</label>
                <input
                    type="email"
                    name="email"
                    value="{{ old('email', data_get($user, 'email')) }}"
                    class="border rounded-md px-3 py-2 w-full"
                    required
                >
            </div>

            <div>
                <label class="block text-sm font-medium mb-1">
                    Contraseña {{ $isEdit ? '(opcional)' : '' }}
                </label>
                <input
                    type="password"
                    name="password"
                    class="border rounded-md px-3 py-2 w-full"
                    {{ $isEdit ? '' : 'required' }}
                >
            </div>

            <div>
                <label class="block text-sm font-medium mb-1">Confirmar contraseña</label>
                <input
                    type="password"
                    name="password_confirmation"
                    class="border rounded-md px-3 py-2 w-full"
                    {{ $isEdit ? '' : 'required' }}
                >
            </div>

            <div>
                <label class="block text-sm font-medium mb-1">Rol</label>
                <select name="role" class="border rounded-md px-3 py-2 w-full" required>
                    @php
                        $role = old('role', data_get($user, 'role', \App\Constants\Roles::DEFAULT));
                        $role = \App\Constants\Roles::normalize($role);
                    @endphp
                    @foreach (\App\Constants\Roles::active() as $option)
                        <option value="{{ $option }}" {{ $role === $option ? 'selected' : '' }}>
                            {{ \App\Constants\Roles::getDisplayName($option) }}
                        </option>
                    @endforeach
                </select>
            </div>

            <div>
                <label class="block text-sm font-medium mb-1">Descripción del docente</label>
                <textarea
                    name="description"
                    rows="4"
                    maxlength="2000"
                    class="border rounded-md px-3 py-2 w-full"
                    placeholder="Experiencia, especialidad y tipo de acompañamiento que ofrece"
                >{{ old('description', data_get($user, 'description')) }}</textarea>
                <p class="text-xs text-gray-500 mt-1">Se mostrará en la app cuando el usuario tenga rol docente.</p>
            </div>

            <div class="flex items-center gap-2">
                @php $active = old('is_active', data_get($user, 'is_active', true)); @endphp
                <input type="checkbox" name="is_active" value="1" {{ $active ? 'checked' : '' }}>
                <label class="text-sm">Usuario activo</label>
            </div>

            <div class="flex gap-2 pt-2 border-t border-gray-200">
                <button type="submit" class="inline-flex items-center justify-center px-4 py-2 rounded-md font-semibold shadow-md border transition-colors"
                    style="background-color:#4c8d93;color:#ffffff;border-color:#3c747a;">
                    Guardar
                </button>
                <a href="{{ route('admin.users.index') }}" class="inline-flex items-center justify-center px-4 py-2 rounded-md font-medium shadow-sm border transition-colors"
                    style="background-color:#374151;color:#ffffff;border-color:#1f2937;">
                    Cancelar
                </a>
            </div>
        </form>
    </div>
@endsection
