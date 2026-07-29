<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Alert;
use App\Models\AuditLog;
use App\Services\FirestoreSyncService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AlertController extends Controller
{
    public function __construct(private readonly FirestoreSyncService $firestore)
    {
    }

    public function index(): View
    {
        return view('admin.alerts.index', [
            'alerts' => Alert::query()->orderBy('sort_order')->orderBy('source')->paginate(20),
        ]);
    }

    public function create(): View
    {
        return view('admin.alerts.create');
    }

    public function store(Request $request): RedirectResponse
    {
        $alert = Alert::query()->create($this->validated($request));
        $this->firestore->syncAlert($alert);
        $this->audit('alert_created', "Alerta creada: {$alert->title}", $alert);

        return redirect()->route('admin.alerts.index')->with('status', 'Alerta creada correctamente.');
    }

    public function edit(Alert $alert): View
    {
        return view('admin.alerts.edit', compact('alert'));
    }

    public function update(Request $request, Alert $alert): RedirectResponse
    {
        $alert->update($this->validated($request));
        $this->firestore->syncAlert($alert);
        $this->audit('alert_updated', "Alerta actualizada: {$alert->title}", $alert);

        return redirect()->route('admin.alerts.index')->with('status', 'Alerta actualizada correctamente.');
    }

    public function destroy(Alert $alert): RedirectResponse
    {
        $this->firestore->deleteAlert($alert);
        $title = $alert->title;
        $alert->delete();
        $this->audit('alert_deleted', "Alerta eliminada: {$title}");

        return redirect()->route('admin.alerts.index')->with('status', 'Alerta eliminada correctamente.');
    }

    private function validated(Request $request): array
    {
        $data = $request->validate([
            'source' => ['required', 'string', 'max:160'],
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:2000'],
            'link_url' => ['nullable', 'url', 'max:2000'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['nullable', 'boolean'],
        ]);
        $data['sort_order'] = $data['sort_order'] ?? 0;
        $data['is_active'] = $request->boolean('is_active');

        return $data;
    }

    private function audit(string $action, string $description, ?Alert $alert = null): void
    {
        AuditLog::log(
            auth()->id(),
            $action,
            $description,
            'alerts',
            request()->ip(),
            request()->userAgent(),
            $alert ? ['alert_id' => $alert->id] : null,
        );
    }
}
