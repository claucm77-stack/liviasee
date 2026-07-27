@extends('admin.layout')

@section('content')
    <div class="mb-6 flex flex-col gap-1">
        <p class="text-sm font-semibold uppercase tracking-wide text-[#4c8d93]">Livi@se</p>
        <h2 class="text-2xl font-black text-gray-800">
            Dashboard de la plataforma
        </h2>
    </div>

    @php
        $activePercent = $stats['users'] > 0 ? round(($stats['activeUsers'] / $stats['users']) * 100) : 0;
        $contentPercent = $stats['contents'] > 0 ? round(($stats['publishedContents'] / $stats['contents']) * 100) : 0;
        $fieldPercent = $stats['fields'] > 0 ? round(($stats['activeFields'] / $stats['fields']) * 100) : 0;
        $microPercent = ($stats['microbusinesses'] ?? 0) > 0 ? round((($stats['activeMicrobusinesses'] ?? 0) / $stats['microbusinesses']) * 100) : 0;
        $maxRole = max($roleStats->max('count') ?? 0, 1);
        $maxModule = max($logsByModule->max() ?? 0, 1);
    @endphp

    <div class="space-y-6">
            <section class="rounded-lg bg-[#4c8d93] p-6 text-white shadow-lg">
                <div class="grid gap-4 lg:grid-cols-[1.5fr_1fr] lg:items-center">
                    <div>
                        <h3 class="text-2xl font-black">Estado general del ecosistema</h3>
                        <p class="mt-2 max-w-2xl text-white/85">
                            Resumen operativo de usuarios, contenidos, campos de micronegocio y actividad registrada para seguimiento académico y técnico.
                        </p>
                    </div>
                    <div class="grid grid-cols-2 gap-3 text-sm">
                        <div class="rounded-lg border border-white/20 bg-white/15 p-3">
                            <p class="text-white/75">Usuarios</p>
                            <p class="text-2xl font-black">{{ $stats['users'] }}</p>
                        </div>
                        <div class="rounded-lg border border-white/20 bg-white/15 p-3">
                            <p class="text-white/75">Eventos</p>
                            <p class="text-2xl font-black">{{ $stats['events'] }}</p>
                        </div>
                        <div class="rounded-lg border border-white/20 bg-white/15 p-3">
                            <p class="text-white/75">Micronegocios</p>
                            <p class="text-2xl font-black">{{ $stats['microbusinesses'] ?? 0 }}</p>
                        </div>
                    </div>
                </div>
            </section>

            <section class="grid gap-4 md:grid-cols-2 xl:grid-cols-5">
                <x-dashboard-card title="Usuarios activos" :value="$stats['activeUsers']" detail="{{ $activePercent }}% del total" icon="personas" />
                <x-dashboard-card title="Contenidos publicados" :value="$stats['publishedContents']" detail="{{ $contentPercent }}% disponibles" icon="contenidos" />
                <x-dashboard-card title="Campos activos" :value="$stats['activeFields']" detail="{{ $fieldPercent }}% configurados" icon="campos" />
                <x-dashboard-card title="Negocios activos" :value="$stats['activeMicrobusinesses'] ?? 0" detail="{{ $microPercent }}% visibles" icon="campos" />
                <x-dashboard-card title="Usuarios inactivos" :value="$stats['inactiveUsers']" detail="Requieren revisión" icon="alertas" />
            </section>

            <section class="grid gap-6 lg:grid-cols-2">
                <div class="liviase-card p-5">
                    <h3 class="text-lg font-black text-gray-800">Usuarios por rol</h3>
                    <div class="mt-5 space-y-4">
                        @foreach ($roleStats as $role)
                            @php $width = $maxRole > 0 ? round(($role['count'] / $maxRole) * 100) : 0; @endphp
                            <div>
                                <div class="mb-2 flex items-center justify-between gap-3 text-sm">
                                    <span class="font-semibold text-gray-700">{{ $role['label'] }}</span>
                                    <span class="font-black text-[#193760]">{{ $role['count'] }}</span>
                                </div>
                                <div class="h-2.5 overflow-hidden rounded-full bg-[#e6e4e4]">
                                    <div class="h-full rounded-full bg-[#193760]" style="width: {{ $width }}%"></div>
                                </div>
                            </div>
                        @endforeach
                    </div>
                </div>

                <div class="liviase-card p-5">
                    <h3 class="text-lg font-black text-gray-800">Actividad por módulo</h3>
                    <div class="mt-5 space-y-4">
                        @forelse ($logsByModule as $module => $total)
                            @php $width = $maxModule > 0 ? round(($total / $maxModule) * 100) : 0; @endphp
                            <div>
                                <div class="mb-2 flex items-center justify-between gap-3 text-sm">
                                    <span class="font-semibold text-gray-700">{{ $module ?: 'general' }}</span>
                                    <span class="font-black text-[#4c8d93]">{{ $total }}</span>
                                </div>
                                <div class="h-2.5 overflow-hidden rounded-full bg-[#e6e4e4]">
                                    <div class="h-full rounded-full bg-[#4c8d93]" style="width: {{ $width }}%"></div>
                                </div>
                            </div>
                        @empty
                            <p class="text-sm text-gray-500">Aún no hay actividad registrada.</p>
                        @endforelse
                    </div>
                </div>
            </section>

            <section class="grid gap-6 lg:grid-cols-2">
                <div class="liviase-card p-5">
                    <h3 class="text-lg font-black text-gray-800">Usuarios recientes</h3>
                    <div class="mt-4 divide-y divide-gray-100">
                        @forelse ($recentUsers as $user)
                            <div class="flex items-center justify-between gap-4 py-3">
                                <div>
                                    <p class="font-bold text-gray-900">{{ $user->name ?: 'Sin nombre' }}</p>
                                    <p class="text-sm text-gray-500">{{ $user->email }}</p>
                                </div>
                                <span class="rounded-full bg-[#e6e4e4] px-3 py-1 text-xs font-bold text-gray-700">
                                    {{ $user->getRoleDisplayName() }}
                                </span>
                            </div>
                        @empty
                            <p class="py-4 text-sm text-gray-500">No hay usuarios recientes.</p>
                        @endforelse
                    </div>
                </div>

                <div class="liviase-card p-5">
                    <h3 class="text-lg font-black text-gray-800">Últimos eventos</h3>
                    <div class="mt-4 divide-y divide-gray-100">
                        @forelse ($recentEvents as $event)
                            <div class="py-3">
                                <div class="flex items-start justify-between gap-4">
                                    <p class="font-bold text-gray-900">{{ $event->title }}</p>
                                    <span class="text-xs font-bold text-[#4c8d93]">Cronograma</span>
                                </div>
                                <p class="mt-1 text-sm text-gray-500">{{ $event->summary }}</p>
                                <p class="mt-1 text-xs text-gray-400">{{ optional($event->published_at ?? $event->created_at)->format('d/m/Y H:i') }}</p>
                            </div>
                        @empty
                            <p class="py-4 text-sm text-gray-500">No hay eventos recientes.</p>
                        @endforelse
                    </div>
                </div>
            </section>
    </div>
@endsection
