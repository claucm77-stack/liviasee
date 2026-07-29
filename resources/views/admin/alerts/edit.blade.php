@extends('admin.layout')

@section('content')
    <div class="bg-white rounded-lg shadow p-5">
        <h2 class="text-lg font-semibold mb-5">Editar alerta</h2>
        <form method="POST" action="{{ route('admin.alerts.update', $alert) }}" class="space-y-5">
            @csrf
            @method('PUT')
            @include('admin.alerts._form', ['submitLabel' => 'Actualizar alerta'])
        </form>
    </div>
@endsection
