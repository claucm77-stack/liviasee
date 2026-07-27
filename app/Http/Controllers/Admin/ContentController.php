<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Content;
use App\Models\ContentCategory;
use App\Services\FirestoreSyncService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class ContentController extends Controller
{
    private const CONTENT_TYPES = [
        'articulo' => 'Artículo',
        'video' => 'Video',
        'pdf' => 'PDF / documento',
        'evento' => 'Evento de cronograma',
    ];

    public function __construct(private readonly FirestoreSyncService $firestore)
    {
    }

    public function index(): View
    {
        $contents = Content::query()
            ->latest()
            ->paginate(15);

        return view('admin.contents.index', compact('contents'));
    }

    public function create(): View
    {
        return view('admin.contents.create', [
            'contentTypes' => self::CONTENT_TYPES,
            'contentCategories' => $this->contentCategories(),
            'bodyData' => [],
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $this->validateContent($request);
        $category = ContentCategory::findOrFail($validated['content_category_id']);

        $slug = $validated['slug'] ?? Str::slug($validated['title']);
        if (empty($slug)) {
            $slug = Str::random(8);
        }

        $content = Content::create([
            'title' => $validated['title'],
            'slug' => $slug,
            'type' => $validated['type'],
            'content_category_id' => $category->id,
            'author_id' => (string) (auth()->user()?->firebase_uid ?: auth()->id()),
            'summary' => $validated['summary'] ?? null,
            'body' => $this->buildBodyPayload($request, $category->name),
            'status' => $validated['status'],
            // Si el admin marca "publicado" pero no envía publicada_at,
            // la API filtra/ordena por published_at. Usamos now() como fallback.
            'published_at' => $this->resolvePublishedAt($request, $validated),
        ]);

        $this->firestore->syncContent($content);
        $this->audit('content_created', "Contenido creado: {$content->title}", 'contents', [
            'content_id' => $content->id,
        ]);

        return redirect()
            ->route('admin.contents.index')
            ->with('status', 'Contenido creado correctamente.');
    }

    public function edit(Content $content): View
    {
        return view('admin.contents.edit', [
            'content' => $content,
            'contentTypes' => self::CONTENT_TYPES,
            'contentCategories' => $this->contentCategories($content->content_category_id),
            'bodyData' => $this->decodeBodyPayload($content),
        ]);
    }

    public function update(Request $request, Content $content): RedirectResponse
    {
        $validated = $this->validateContent($request, $content);
        $category = ContentCategory::findOrFail($validated['content_category_id']);

        $slug = $validated['slug'] ?? Str::slug($validated['title']);
        if (empty($slug)) {
            $slug = Str::random(8);
        }

        $content->update([
            'title' => $validated['title'],
            'slug' => $slug,
            'type' => $validated['type'],
            'content_category_id' => $category->id,
            'summary' => $validated['summary'] ?? null,
            'body' => $this->buildBodyPayload($request, $category->name),
            'status' => $validated['status'],
            // Igual que en store(): si publican sin publicada_at, usamos fallback.
            'published_at' => $this->resolvePublishedAt($request, $validated),
        ]);

        $this->firestore->syncContent($content);
        $this->audit('content_updated', "Contenido actualizado: {$content->title}", 'contents', [
            'content_id' => $content->id,
        ]);

        return redirect()
            ->route('admin.contents.index')
            ->with('status', 'Contenido actualizado correctamente.');
    }

    public function destroy(Content $content): RedirectResponse
    {
        $title = $content->title;
        $this->firestore->deleteContent($content);
        $content->delete();
        $this->audit('content_deleted', "Contenido eliminado: {$title}", 'contents');

        return redirect()
            ->route('admin.contents.index')
            ->with('status', 'Contenido eliminado correctamente.');
    }

    private function validateContent(Request $request, ?Content $content = null): array
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'slug' => [
                'nullable',
                'string',
                'max:255',
                $content
                    ? Rule::unique('contents', 'slug')->ignore($content->id)
                    : Rule::unique('contents', 'slug'),
            ],
            'type' => ['required', Rule::in(array_keys(self::CONTENT_TYPES))],
            'summary' => ['nullable', 'string'],
            'image_url' => ['nullable', 'url', 'max:500'],
            'content_category_id' => [
                'required',
                Rule::exists('content_categories', 'id')->where(fn ($query) => $query->where('is_active', true)),
            ],
            'status' => ['required', 'in:borrador,publicado,archivado'],
            'published_at' => ['nullable', 'date'],
            'author_name' => ['nullable', 'string', 'max:180'],
        ]);

        $specificRules = match ($validated['type']) {
            'articulo' => [
                'article_body' => ['required', 'string'],
                'reading_time' => ['nullable', 'integer', 'min:1', 'max:240'],
            ],
            'video' => [
                'video_url' => ['required', 'url', 'max:500'],
                'video_duration' => ['nullable', 'string', 'max:50'],
                'transcript' => ['nullable', 'string'],
            ],
            'pdf' => [
                'pdf_url' => ['required', 'url', 'max:500'],
                'pages' => ['nullable', 'integer', 'min:1', 'max:10000'],
                'document_instructions' => ['nullable', 'string'],
            ],
            'evento' => [
                'event_starts_at' => ['required', 'date'],
                'event_ends_at' => ['nullable', 'date', 'after_or_equal:event_starts_at'],
                'event_location' => ['nullable', 'string', 'max:255'],
                'event_modality' => ['required', 'in:presencial,virtual,hibrido'],
                'registration_url' => ['nullable', 'url', 'max:500'],
                'event_agenda' => ['nullable', 'string'],
            ],
        };

        $request->validate($specificRules);

        return $validated;
    }

    private function buildBodyPayload(Request $request, string $categoryName): string
    {
        $type = (string) $request->input('type', 'articulo');
        $payload = [
            'type' => $type,
            'category' => $categoryName,
            'image_url' => $request->input('image_url'),
        ];

        $payload['data'] = match ($type) {
            'video' => [
                'video_url' => $request->input('video_url'),
                'duration' => $request->input('video_duration'),
                'transcript' => $request->input('transcript'),
            ],
            'pdf' => [
                'pdf_url' => $request->input('pdf_url'),
                'pages' => $request->input('pages'),
                'instructions' => $request->input('document_instructions'),
            ],
            'evento' => [
                'starts_at' => $request->input('event_starts_at'),
                'ends_at' => $request->input('event_ends_at'),
                'location' => $request->input('event_location'),
                'modality' => $request->input('event_modality'),
                'registration_url' => $request->input('registration_url'),
                'agenda' => $request->input('event_agenda'),
            ],
            default => [
                'body' => $request->input('article_body'),
                'author_name' => $request->input('author_name'),
                'reading_time' => $request->input('reading_time'),
            ],
        };
        $payload['data']['author_name'] = $request->input('author_name');

        return json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }

    private function decodeBodyPayload(Content $content): array
    {
        $decoded = json_decode((string) $content->body, true);
        if (!is_array($decoded) || !isset($decoded['data'])) {
            return [
                'type' => $content->type,
                'category' => $content->contentCategory?->name ?? '',
                'image_url' => '',
                'data' => [
                    'body' => (string) ($content->body ?? ''),
                ],
            ];
        }

        $decoded['category'] = $content->contentCategory?->name ?? ($decoded['category'] ?? '');

        return $decoded;
    }

    private function resolvePublishedAt(Request $request, array $validated): mixed
    {
        $status = (string) ($validated['status'] ?? '');
        $publishedAt = $validated['published_at'] ?? null;

        // Si se marcó como publicado y no se envió published_at, usamos now() para
        // asegurar que la API pueda ordenar/mostrar consistentemente.
        if ($status === 'publicado' && empty($publishedAt)) {
            return now();
        }

        return $publishedAt;
    }

    private function contentCategories(?int $includeCategoryId = null)
    {
        return ContentCategory::query()
            ->where(function ($query) use ($includeCategoryId) {
                $query->where('is_active', true);
                if ($includeCategoryId) {
                    $query->orWhere(
                        $query->getModel()->getQualifiedKeyName(),
                        $includeCategoryId,
                    );
                }
            })
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();
    }


    private function audit(string $action, string $description, string $module, ?array $metadata = null): void
    {
        AuditLog::log(
            auth()->id(),
            $action,
            $description,
            $module,
            request()->ip(),
            request()->userAgent(),
            $metadata,
        );
    }
}
