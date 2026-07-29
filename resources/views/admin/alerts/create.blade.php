@extends('admin.layout')

@section('content')
    <div class="bg-white rounded-lg shadow p-5">
        <h2 class="text-lg font-semibold mb-5">Nueva alerta</h2>
        <form method="POST" action="{{ route('admin.alerts.store') }}" class="space-y-5">
            @csrf
            @include('admin.alerts._form', ['submitLabel' => 'Guardar alerta'])
        </form>
    </div>
@endsection
