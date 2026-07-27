<?php

use App\Constants\Roles;
use App\Http\Controllers\Admin\AuditLogController;
use App\Http\Controllers\Admin\BusinessEntityController;
use App\Http\Controllers\Admin\ContentController;
use App\Http\Controllers\Admin\ContentCategoryController;
use App\Http\Controllers\Admin\MicrobusinessFieldController;
use App\Http\Controllers\Admin\MicrobusinessController;
use App\Http\Controllers\Admin\PlatformSettingController;
use App\Http\Controllers\Admin\UserController;
use App\Models\AuditLog;
use App\Models\Content;
use App\Models\Microbusiness;
use App\Models\MicrobusinessField;
use App\Models\User;
use App\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

Route::get('/', function () {
    return auth()->check()
        ? redirect()->route('dashboard')
        : redirect()->route('login');
});

Route::get('/politica-privacidad-liviase.html', function () {
    return response(
        file_get_contents(public_path('politica-privacidad-liviase.html')),
        200,
        ['Content-Type' => 'text/html; charset=UTF-8'],
    );
});

Route::get('/dashboard', function () {
    $hasContents = Schema::hasTable('contents');
    $hasFields = Schema::hasTable('microbusiness_fields');
    $hasMicrobusinesses = Schema::hasTable('microbusinesses');
    $hasLogs = Schema::hasTable('audit_logs');

    $usersByRole = User::query()
        ->selectRaw('role, count(*) as total')
        ->groupBy('role')
        ->pluck('total', 'role');

    $roleStats = collect(Roles::active())->map(fn (string $role) => [
        'label' => Roles::getDisplayName($role),
        'count' => (int) ($usersByRole[$role] ?? 0),
    ]);

    $contentByStatus = $hasContents
        ? Content::query()
            ->selectRaw('status, count(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status')
        : collect();
    $eventCount = $hasContents
        ? Content::query()->where('type', 'evento')->count()
        : 0;

    $logsByModule = $hasLogs
        ? AuditLog::query()
            ->selectRaw('module, count(*) as total')
            ->groupBy('module')
            ->orderByDesc('total')
            ->limit(5)
            ->pluck('total', 'module')
        : collect();

    return view('dashboard', [
        'stats' => [
            'users' => User::count(),
            'activeUsers' => User::where('is_active', true)->count(),
            'inactiveUsers' => User::where('is_active', false)->count(),
            'contents' => $hasContents ? Content::count() : 0,
            'publishedContents' => (int) ($contentByStatus['publicado'] ?? $contentByStatus['published'] ?? $contentByStatus['activo'] ?? 0),
            'draftContents' => (int) ($contentByStatus['borrador'] ?? $contentByStatus['draft'] ?? $contentByStatus['inactivo'] ?? 0),
            'fields' => $hasFields ? MicrobusinessField::count() : 0,
            'activeFields' => $hasFields ? MicrobusinessField::where('is_active', true)->count() : 0,
            'microbusinesses' => $hasMicrobusinesses ? Microbusiness::count() : 0,
            'activeMicrobusinesses' => $hasMicrobusinesses ? Microbusiness::where('status', 'activo')->count() : 0,
            'events' => $eventCount,
            'logs' => $hasLogs ? AuditLog::count() : 0,
        ],
        'roleStats' => $roleStats,
        'logsByModule' => $logsByModule,
        'recentLogs' => $hasLogs ? AuditLog::query()->latest()->limit(6)->get() : collect(),
        'recentEvents' => $hasContents
            ? Content::query()
                ->where('type', 'evento')
                ->latest('published_at')
                ->latest('created_at')
                ->limit(6)
                ->get()
            : collect(),
        'recentUsers' => User::query()->latest()->limit(5)->get(),
    ]);
})->middleware(['auth', 'verified', 'admin'])->name('dashboard');

Route::middleware('auth')->group(function () {
    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');

    Route::prefix('admin')->name('admin.')->middleware('admin')->group(function () {
        Route::get('/', fn () => redirect()->route('admin.users.index'))->name('index');
        Route::resource('users', UserController::class)->except(['show']);
        Route::resource('microbusiness-fields', MicrobusinessFieldController::class)->except(['show']);
        Route::resource('microbusinesses', MicrobusinessController::class)->except(['show']);
        Route::resource('contents', ContentController::class)->except(['show']);
        Route::resource('content-categories', ContentCategoryController::class)->except(['show']);
        Route::resource('entities', BusinessEntityController::class)->except(['show']);
        Route::get('/logs', [AuditLogController::class, 'index'])->name('logs.index');
        Route::get('/settings', [PlatformSettingController::class, 'edit'])->name('settings.edit');
        Route::patch('/settings', [PlatformSettingController::class, 'update'])->name('settings.update');
    });
});

require __DIR__.'/auth.php';
