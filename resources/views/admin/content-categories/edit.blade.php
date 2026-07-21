@extends('admin.layout')

@section('content')
    <div class="max-w-3xl rounded-lg bg-white p-6 shadow">
        <h2 class="text-lg font-semibold">Editar categoría</h2>
        <form method="POST" action="{{ route('admin.content-categories.update', $contentCategory) }}" enctype="multipart/form-data" class="mt-5 space-y-5">
            @csrf
            @method('PUT')
            @include('admin.content-categories._form', ['submitLabel' => 'Guardar cambios'])
        </form>
    </div>
@endsection
