@extends('admin.layout')

@section('content')
    <div class="max-w-3xl rounded-lg bg-white p-6 shadow">
        <h2 class="text-lg font-semibold">Nueva categoría de contenidos</h2>
        <p class="mt-1 text-sm text-gray-600">Crea la tarjeta con imagen que se mostrará al inicio de la app.</p>
        <form method="POST" action="{{ route('admin.content-categories.store') }}" enctype="multipart/form-data" class="mt-5 space-y-5">
            @csrf
            @include('admin.content-categories._form', ['submitLabel' => 'Crear categoría'])
        </form>
    </div>
@endsection
