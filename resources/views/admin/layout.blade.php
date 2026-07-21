<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Livi@se | Panel San Martín</title>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="admin-shell liviase-shell text-gray-900 min-h-screen">
    <header class="liviase-nav sanmartin-admin-header" style="position: relative; overflow: hidden; min-height: 126px; background: #2d777d;">
        <img
            src="{{ asset('images/institutional/san_martin_header_corner.png') }}"
            alt=""
            class="sanmartin-header-corner"
            style="position: absolute; top: 0; right: 0; width: 104px; height: 104px; object-fit: contain; object-position: top right; pointer-events: none;"
            aria-hidden="true"
        >
        <div class="sanmartin-header-inner max-w-6xl mx-auto px-4 py-3" style="position: relative; z-index: 1; max-width: 1152px; margin-left: auto; margin-right: auto; padding: 18px 16px;">
            <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between" style="display: flex; align-items: center; justify-content: space-between; gap: 24px; min-height: 86px; flex-wrap: wrap;">
                <div class="sanmartin-header-brand" style="display: grid; gap: 6px; align-content: center;">
                    <img
                        src="{{ asset('images/institutional/san_martin_logo_white.png') }}"
                        alt="Fundación Universitaria San Martín"
                        class="sanmartin-nav-logo"
                        style="display: block; width: 220px; max-width: 56vw; height: auto; max-height: 62px; object-fit: contain;"
                    >
                    <h1 class="text-lg font-black leading-tight sm:text-xl">Administrador de Plataforma</h1>
                </div>
                <div>
                    <div class="flex flex-col gap-2 md:items-end">
                        <nav class="sanmartin-admin-nav flex flex-wrap items-center justify-start gap-1 text-sm md:justify-end">
                            <a href="{{ route('dashboard') }}">Dashboard</a>
                            @if (auth()->user()?->isAdmin())
                                <a href="{{ route('admin.users.index') }}">Usuarios</a>
                                <a href="{{ route('admin.microbusiness-fields.index') }}">Campos</a>
                                <a href="{{ route('admin.microbusinesses.index') }}">Micronegocios</a>
                                <a href="{{ route('admin.contents.index') }}">Contenidos</a>
                                <a href="{{ route('admin.content-categories.index') }}">Categorías</a>
                                <a href="{{ route('admin.entities.index') }}">Entidades</a>
                                <a href="{{ route('admin.logs.index') }}">Logs</a>
                                <a href="{{ route('admin.settings.edit') }}">Configuración</a>
                            @endif
                        </nav>

                        @auth
                            <form method="POST" action="{{ route('logout') }}" class="m-0 flex items-center gap-2">
                                @csrf
                                <span class="hidden text-xs font-semibold text-white/80 sm:inline">
                                    {{ auth()->user()->name ?: auth()->user()->email }}
                                </span>
                                <button
                                    type="submit"
                                    class="rounded-md border border-white/40 bg-white/15 px-3 py-2 text-sm font-bold text-white shadow-sm hover:bg-white/25"
                                >
                                    Cerrar sesión
                                </button>
                            </form>
                        @endauth
                    </div>
                </div>
            </div>
        </div>
    </header>

    <main class="max-w-6xl mx-auto px-4 py-6">
        @if (session('status'))
            <div class="mb-4 rounded-md bg-green-100 border border-green-300 text-green-800 px-4 py-3">
                {{ session('status') }}
            </div>
        @endif

        @if ($errors->any())
            <div class="mb-4 rounded-md bg-red-100 border border-red-300 text-red-800 px-4 py-3">
                <p class="font-medium mb-2">Hay errores en el formulario:</p>
                <ul class="list-disc pl-5 text-sm">
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        @yield('content')
    </main>
    <footer class="sanmartin-admin-footer" style="margin-top: auto; background: #143658; color: #fff; overflow: hidden;">
        <div class="sanmartin-footer-inner max-w-6xl mx-auto px-4" style="display: flex; min-height: 92px; align-items: center; justify-content: space-between; gap: 24px; max-width: 1152px; margin-left: auto; margin-right: auto; padding: 18px 16px; flex-wrap: wrap;">
            <a href="https://sanmartin.edu.co/" target="_blank" rel="noopener noreferrer" class="sanmartin-footer-logo-link">
                <img
                    src="{{ asset('images/institutional/san_martin_logo_white.png') }}"
                    alt="Fundación Universitaria San Martín"
                    class="sanmartin-footer-logo"
                    style="display: block; width: 220px; max-width: 72vw; height: auto; max-height: 58px; object-fit: contain;"
                >
            </a>

            <div class="sanmartin-footer-meta" style="display: flex; flex-direction: column; align-items: flex-end; gap: 10px; text-align: right;">
                <div class="sanmartin-footer-social" aria-label="Redes sociales de la Universidad San Martín" style="display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 8px;">
                    <a href="https://www.facebook.com/USanMartinOficial" target="_blank" rel="noopener noreferrer" aria-label="Facebook">
                        <img src="{{ asset('images/institutional/social_facebook_20260604.png') }}" alt="" style="width: 22px; height: 22px; object-fit: contain;">
                    </a>
                    <a href="https://www.instagram.com/usanmartinoficial/" target="_blank" rel="noopener noreferrer" aria-label="Instagram">
                        <img src="{{ asset('images/institutional/social_instagram_20260604.png') }}" alt="" style="width: 22px; height: 22px; object-fit: contain;">
                    </a>
                    <a href="https://x.com/USanMartinCO" target="_blank" rel="noopener noreferrer" aria-label="X">
                        <img src="{{ asset('images/institutional/social_x_20260604.png') }}" alt="" style="width: 22px; height: 22px; object-fit: contain;">
                    </a>
                    <a href="https://www.youtube.com/@USanMartinOficial" target="_blank" rel="noopener noreferrer" aria-label="YouTube">
                        <img src="{{ asset('images/institutional/social_youtube_20260604.png') }}" alt="" style="width: 22px; height: 22px; object-fit: contain;">
                    </a>
                    <a href="https://www.linkedin.com/school/fundaci%C3%B3n-universitaria-san-mart%C3%ADn" target="_blank" rel="noopener noreferrer" aria-label="LinkedIn">
                        <img src="{{ asset('images/institutional/social_linkedin_20260604.png') }}" alt="" style="width: 22px; height: 22px; object-fit: contain;">
                    </a>
                </div>
                <p>&copy; {{ date('Y') }} Fundación Universitaria San Martín</p>
            </div>
        </div>
    </footer>
</body>
</html>
