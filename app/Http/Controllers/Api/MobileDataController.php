<?php

namespace App\Http\Controllers\Api;

use App\Constants\Roles;
use App\Http\Controllers\Controller;
use App\Models\BusinessEntity;
use App\Models\AuditLog;
use App\Models\Alert;
use App\Models\Content;
use App\Models\ContentCategory;
use App\Models\Microbusiness;
use App\Models\User;
use App\Services\FirestoreSyncService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

class MobileDataController extends Controller
{
    public function __construct(private readonly FirestoreSyncService $firestore)
    {
    }

    public function categories(): JsonResponse
    {
        $rows = ContentCategory::query()->orderBy('sort_order')->orderBy('name')->get()->map($this->categoryData(...));
        return response()->json(['data' => $rows]);
    }

    public function alerts(Request $request): JsonResponse
    {
        $isAdmin = Roles::normalize($request->user()->role) === Roles::ADMIN_TI;
        $rows = Alert::query()
            ->when(! $isAdmin, fn ($query) => $query->where('is_active', true))
            ->orderBy('sort_order')
            ->orderBy('source')
            ->get()
            ->map($this->alertData(...));

        return response()->json(['data' => $rows]);
    }

    public function saveAlert(Request $request): JsonResponse
    {
        $this->requireAdmin($request);
        $data = $request->validate([
            'id' => ['nullable', 'integer', 'min:1'],
            'source' => ['required', 'string', 'max:160'],
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:2000'],
            'linkUrl' => ['nullable', 'url', 'max:2000'],
            'sortOrder' => ['nullable', 'integer', 'min:0'],
            'isActive' => ['nullable', 'boolean'],
        ]);
        $alert = filled($data['id'] ?? null)
            ? Alert::query()->findOrFail((int) $data['id'])
            : new Alert();
        $alert->fill([
            'source' => $data['source'],
            'title' => $data['title'],
            'description' => $data['description'] ?? null,
            'link_url' => $data['linkUrl'] ?? null,
            'sort_order' => $data['sortOrder'] ?? 0,
            'is_active' => $data['isActive'] ?? true,
        ])->save();
        $this->firestore->syncAlert($alert);

        return response()->json(
            ['data' => $this->alertData($alert)],
            $alert->wasRecentlyCreated ? 201 : 200,
        );
    }

    public function deleteAlert(Request $request, Alert $alert): JsonResponse
    {
        $this->requireAdmin($request);
        $this->firestore->deleteAlert($alert);
        $alert->delete();

        return response()->json([], 204);
    }

    public function users(Request $request): JsonResponse
    {
        $this->requireSensitiveAccess($request);
        return response()->json(['data' => User::query()->orderBy('name')->get()->map(fn (User $user) => [
            'uid' => (string) ($user->firebase_uid ?: $user->id),
            'name' => $user->name,
            'email' => $user->email,
            'rol' => $user->role,
            'role' => $user->role,
            'photoUrl' => $user->photoUrl(),
            'isActive' => $user->is_active,
            'createdAt' => optional($user->created_at)?->toIso8601String(),
        ])]);
    }

    public function teachers(): JsonResponse
    {
        $teacherRoles = [
            Roles::DOCENTE,
            Roles::DOCENTE_ADMIN,
            Roles::LEGACY_EDUCADOR,
            Roles::LEGACY_COORD,
            Roles::LEGACY_COORDINADOR,
        ];

        $teachers = User::query()
            ->whereIn('role', $teacherRoles)
            ->where('is_active', true)
            ->orderBy('name')
            ->get()
            ->map(fn (User $user) => [
                'uid' => (string) ($user->firebase_uid ?: $user->id),
                'name' => $user->name,
                'role' => Roles::normalize($user->role),
                'roleLabel' => Roles::getDisplayName($user->role),
                'photoUrl' => $user->photoUrl(),
            ]);

        return response()->json(['data' => $teachers]);
    }

    public function logs(Request $request): JsonResponse
    {
        $this->requireSensitiveAccess($request);
        $query = AuditLog::query()->with('user')->latest();
        if ($request->filled('module')) {
            $query->where('module', $request->string('module')->toString());
        }
        $limit = max(1, min((int) $request->integer('limit', 100), 200));

        return response()->json([
            'data' => $query->limit($limit)->get()->map($this->logData(...)),
        ]);
    }

    public function saveLog(Request $request): JsonResponse
    {
        $this->requireSensitiveAccess($request);
        $data = $request->validate([
            'accion' => ['required', 'string', 'max:255'],
            'modulo' => ['required', 'string', 'max:100'],
            'origen' => ['nullable', 'string', 'max:50'],
            'detalle' => ['nullable', 'string', 'max:2000'],
        ]);
        $log = AuditLog::log(
            $request->user()->id,
            $data['accion'],
            (string) ($data['detalle'] ?? $data['accion']),
            $data['modulo'],
            $request->ip(),
            $request->userAgent(),
            ['origin' => (string) ($data['origen'] ?? 'mobile')],
        );

        return response()->json(['data' => $this->logData($log->load('user'))], 201);
    }

    public function saveProfile(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'photoUrl' => ['nullable', 'string', 'max:2000'],
        ]);
        $user = $request->user();
        $updates = ['name' => $data['name']];
        $requestedPhoto = (string) ($data['photoUrl'] ?? '');
        if ($requestedPhoto !== $user->photoUrl()) {
            if ($user->photo_path) {
                Storage::disk('public')->delete($user->photo_path);
            }
            $updates['photo_path'] = null;
            $updates['photo_url'] = $requestedPhoto !== '' ? $requestedPhoto : null;
        }
        $user->update($updates);
        return response()->json(['data' => [
            'uid' => (string) ($user->firebase_uid ?: $user->id),
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'photoUrl' => $user->photoUrl(),
        ]]);
    }

    public function saveProfilePhoto(Request $request): JsonResponse
    {
        $request->validate([
            'photo' => ['required', 'image', 'mimes:jpeg,jpg,png,webp', 'max:5120'],
        ]);

        $user = $request->user();
        if ($user->photo_path) {
            Storage::disk('public')->delete($user->photo_path);
        }
        $path = $request->file('photo')->store('profiles', 'public');
        $user->update(['photo_path' => $path, 'photo_url' => null]);

        return response()->json(['data' => ['photoUrl' => $user->photoUrl()]]);
    }

    public function profilePhoto(User $user): StreamedResponse
    {
        abort_unless(
            $user->photo_path && Storage::disk('public')->exists($user->photo_path),
            404,
        );

        return Storage::disk('public')->response($user->photo_path);
    }

    public function updateUser(Request $request, string $id): JsonResponse
    {
        $this->requireAdmin($request);
        $data = $request->validate([
            'role' => ['required', 'in:'.implode(',', Roles::active())],
            'isActive' => ['required', 'boolean'],
        ]);
        $user = ctype_digit($id)
            ? User::query()->find((int) $id)
            : User::query()->where('firebase_uid', $id)->first();
        abort_unless($user, 404);
        $user->update(['role' => $data['role'], 'is_active' => $data['isActive']]);
        return response()->json(['data' => [
            'uid' => (string) ($user->firebase_uid ?: $user->id),
            'name' => $user->name, 'email' => $user->email,
            'role' => $user->role, 'rol' => $user->role,
            'isActive' => $user->is_active,
        ]]);
    }

    public function saveCategory(Request $request): JsonResponse
    {
        $this->requireAdmin($request);
        $data = $request->validate([
            'id' => ['nullable', 'string', 'max:191'],
            'nombre' => ['required', 'string', 'max:120'],
            'scope' => ['required', 'in:contenidos,micronegocios'],
            'descripcion' => ['nullable', 'string', 'max:500'],
            'imageUrl' => ['nullable', 'url', 'max:2000'],
            'orden' => ['nullable', 'integer', 'min:0'],
            'isActive' => ['nullable', 'boolean'],
        ]);
        $category = $this->findShared(ContentCategory::query(), $data['id'] ?? null) ?? new ContentCategory();
        $category->fill([
            'external_id' => $category->exists ? $category->external_id : $this->externalId($data['id'] ?? null),
            'name' => $data['nombre'],
            'slug' => $this->uniqueSlug(ContentCategory::class, $data['nombre'], $category),
            'scope' => $data['scope'],
            'description' => $data['descripcion'] ?? null,
            'image_url' => $data['imageUrl'] ?? null,
            'sort_order' => $data['orden'] ?? 0,
            'is_active' => $data['isActive'] ?? true,
        ])->save();
        $this->firestore->syncContentCategory($category);
        return response()->json(['data' => $this->categoryData($category)], $category->wasRecentlyCreated ? 201 : 200);
    }

    public function deleteCategory(Request $request, string $id): JsonResponse
    {
        $this->requireAdmin($request);
        $category = $this->findShared(ContentCategory::query(), $id);
        abort_unless($category, 404);
        abort_if($category->contents()->exists(), 422, 'La categoría tiene contenidos asociados.');
        $this->firestore->deleteContentCategory($category);
        $category->delete();
        return response()->json([], 204);
    }

    public function contents(Request $request): JsonResponse
    {
        $canManage = Roles::canManageContent($request->user()->role)
            || Roles::normalize($request->user()->role) === Roles::ADMIN_TI;
        $rows = Content::query()
            ->with('contentCategory')
            ->when(! $canManage, fn ($query) => $query->where('status', 'publicado'))
            ->latest()
            ->get()
            ->map($this->contentData(...));
        return response()->json(['data' => $rows]);
    }

    public function saveContent(Request $request): JsonResponse
    {
        $this->requireContentManager($request);
        $data = $request->validate([
            'id' => ['nullable', 'string', 'max:191'],
            'titulo' => ['required', 'string', 'max:255'],
            'descripcion' => ['nullable', 'string'],
            'tipo' => ['required', 'in:texto,video,pdf,evento'],
            'url' => ['nullable', 'string', 'max:2000'],
            'contenido' => ['nullable', 'string'],
            'imagen' => ['nullable', 'string', 'max:2000'],
            'categoria' => ['nullable', 'string', 'max:120'],
            'autorId' => ['nullable', 'string', 'max:191'],
            'autorNombre' => ['nullable', 'string', 'max:180'],
            'fechaCreacion' => ['nullable', 'date'],
            'estado' => ['required', 'in:activo,inactivo'],
            'destacado' => ['nullable', 'boolean'],
            'favoritos' => ['nullable', 'array'],
            'vistos' => ['nullable', 'array'],
        ]);
        $content = $this->findShared(Content::query(), $data['id'] ?? null) ?? new Content();
        $category = filled($data['categoria'] ?? null)
            ? ContentCategory::query()->where('name', $data['categoria'])->first()
            : null;
        $laravelType = $data['tipo'] === 'texto' ? 'articulo' : $data['tipo'];
        $payloadData = match ($laravelType) {
            'video' => ['video_url' => $data['url'] ?? '', 'transcript' => $data['contenido'] ?? ''],
            'pdf' => ['pdf_url' => $data['url'] ?? '', 'instructions' => $data['contenido'] ?? ''],
            'evento' => ['registration_url' => $data['url'] ?? '', 'agenda' => $data['contenido'] ?? ''],
            default => ['body' => $data['contenido'] ?? '', 'author_name' => $data['autorNombre'] ?? ''],
        };
        $payloadData['author_name'] = $data['autorNombre'] ?? '';
        $content->fill([
            'external_id' => $content->exists ? $content->external_id : $this->externalId($data['id'] ?? null),
            'title' => $data['titulo'],
            'slug' => $this->uniqueSlug(Content::class, $data['titulo'], $content),
            'type' => $laravelType,
            'content_category_id' => $category?->id,
            'author_id' => $data['autorId'] ?? null,
            'summary' => $data['descripcion'] ?? null,
            'body' => json_encode(['type' => $laravelType, 'category' => $data['categoria'] ?? '', 'image_url' => $data['imagen'] ?? '', 'data' => $payloadData], JSON_UNESCAPED_UNICODE),
            'status' => $data['estado'] === 'activo' ? 'publicado' : 'borrador',
            'featured' => $data['destacado'] ?? false,
            'favorites' => $data['favoritos'] ?? [],
            'views' => $data['vistos'] ?? [],
            'published_at' => $data['estado'] === 'activo' ? ($content->published_at ?? now()) : null,
        ])->save();
        $this->firestore->syncContent($content);
        return response()->json(['data' => $this->contentData($content->load('contentCategory'))], $content->wasRecentlyCreated ? 201 : 200);
    }

    public function deleteContent(Request $request, string $id): JsonResponse
    {
        $this->requireContentManager($request);
        $content = $this->findShared(Content::query(), $id);
        abort_unless($content, 404);
        $this->firestore->deleteContent($content);
        $content->delete();
        return response()->json([], 204);
    }

    public function microbusinesses(): JsonResponse
    {
        return response()->json(['data' => Microbusiness::query()->latest()->get()->map($this->microbusinessData(...))]);
    }

    public function saveMicrobusiness(Request $request): JsonResponse
    {
        $data = $request->validate([
            'id' => ['nullable', 'string', 'max:191'], 'nombre' => ['required', 'string', 'max:255'],
            'descripcion' => ['nullable', 'string'], 'categoria' => ['nullable', 'string', 'max:120'],
            'direccion' => ['nullable', 'string'], 'latitud' => ['required', 'numeric'], 'longitud' => ['required', 'numeric'],
            'mapsUrl' => ['nullable', 'string'], 'imagen' => ['nullable', 'string'], 'propietarioId' => ['nullable', 'string'],
            'contacto' => ['nullable', 'string'], 'horario' => ['nullable', 'string'], 'estado' => ['required', 'in:activo,inactivo'],
            'fechaCreacion' => ['nullable', 'date'], 'favoritos' => ['nullable', 'array'], 'ratingPromedio' => ['nullable', 'numeric'],
            'totalCalificaciones' => ['nullable', 'integer'], 'campos' => ['nullable', 'array'],
        ]);
        $business = $this->findShared(Microbusiness::query(), $data['id'] ?? null) ?? new Microbusiness();
        $this->authorizeBusiness($request, $business, $data['propietarioId'] ?? null);
        $business->fill([
            'external_id' => $business->exists ? $business->external_id : $this->externalId($data['id'] ?? null),
            'name' => $data['nombre'], 'description' => $data['descripcion'] ?? null, 'category' => $data['categoria'] ?? null,
            'address' => $data['direccion'] ?? null, 'latitude' => $data['latitud'], 'longitude' => $data['longitud'],
            'maps_url' => $data['mapsUrl'] ?? null, 'image_url' => $data['imagen'] ?? null,
            'owner_id' => $data['propietarioId'] ?? $request->user()->firebase_uid, 'contact' => $data['contacto'] ?? null,
            'schedule' => $data['horario'] ?? null, 'status' => $data['estado'],
            'created_on_app_at' => $data['fechaCreacion'] ?? now(), 'favorites' => $data['favoritos'] ?? [],
            'average_rating' => $data['ratingPromedio'] ?? null, 'ratings_count' => $data['totalCalificaciones'] ?? 0,
            'custom_fields' => $data['campos'] ?? [],
        ])->save();
        $this->firestore->syncMicrobusiness($business);
        return response()->json(['data' => $this->microbusinessData($business)], $business->wasRecentlyCreated ? 201 : 200);
    }

    public function deleteMicrobusiness(Request $request, string $id): JsonResponse
    {
        $business = $this->findShared(Microbusiness::query(), $id);
        abort_unless($business, 404);
        $this->authorizeBusiness($request, $business, $business->owner_id);
        $this->firestore->deleteMicrobusiness($business);
        $business->delete();
        return response()->json([], 204);
    }

    public function rateMicrobusiness(Request $request, string $id): JsonResponse
    {
        $business = $this->findShared(Microbusiness::query(), $id);
        abort_unless($business, 404);
        $data = $request->validate([
            'rating' => ['required', 'numeric', 'min:1', 'max:5'],
        ]);
        $total = (int) ($business->ratings_count ?? 0);
        $average = (float) ($business->average_rating ?? 0);
        $newTotal = $total + 1;
        $newAverage = round((($average * $total) + (float) $data['rating']) / $newTotal, 2);
        $business->update([
            'average_rating' => $newAverage,
            'ratings_count' => $newTotal,
        ]);
        return response()->json(['data' => $this->microbusinessData($business)]);
    }

    public function toggleMicrobusinessFavorite(Request $request, string $id): JsonResponse
    {
        $business = $this->findShared(Microbusiness::query(), $id);
        abort_unless($business, 404);
        $userId = (string) ($request->user()->firebase_uid ?: $request->user()->id);
        $favorites = collect($business->favorites ?? [])->map(fn ($value) => (string) $value);
        $favorites = $favorites->contains($userId)
            ? $favorites->reject(fn ($value) => $value === $userId)
            : $favorites->push($userId);
        $business->update(['favorites' => $favorites->values()->all()]);
        $this->firestore->syncMicrobusiness($business);

        return response()->json(['data' => $this->microbusinessData($business)]);
    }

    public function saveMicrobusinessImage(Request $request, string $id): JsonResponse
    {
        $business = $this->findShared(Microbusiness::query(), $id);
        abort_unless($business, 404);
        $this->authorizeBusiness($request, $business, $business->owner_id);
        $request->validate([
            'image' => ['required', 'image', 'mimes:jpeg,jpg,png,webp', 'max:5120'],
        ]);

        if ($business->image_path) {
            Storage::disk('public')->delete($business->image_path);
        }
        $path = $request->file('image')->store('microbusinesses', 'public');
        $business->update(['image_path' => $path, 'image_url' => null]);
        $this->firestore->syncMicrobusiness($business);

        return response()->json(['data' => $this->microbusinessData($business)]);
    }

    public function microbusinessImage(Microbusiness $microbusiness): StreamedResponse
    {
        abort_unless(
            $microbusiness->image_path && Storage::disk('public')->exists($microbusiness->image_path),
            404,
        );

        return Storage::disk('public')->response($microbusiness->image_path);
    }

    public function entities(): JsonResponse
    {
        return response()->json(['data' => BusinessEntity::query()->latest()->get()->map($this->entityData(...))]);
    }

    public function entityImage(BusinessEntity $businessEntity): StreamedResponse
    {
        abort_unless(
            $businessEntity->image_path && Storage::disk('public')->exists($businessEntity->image_path),
            404,
        );
        return Storage::disk('public')->response($businessEntity->image_path);
    }

    public function saveEntity(Request $request): JsonResponse
    {
        $this->requireAdmin($request);
        $data = $request->validate([
            'id' => ['nullable', 'string', 'max:191'], 'name' => ['required', 'string', 'max:255'],
            'imageUrl' => ['nullable', 'string', 'max:2000'], 'mainUrl' => ['nullable', 'string', 'max:2000'],
            'createdAt' => ['nullable', 'date'], 'resources' => ['nullable', 'array'],
            'resources.*.name' => ['required', 'string'], 'resources.*.url' => ['required', 'string'],
            'resources.*.type' => ['required', 'in:link,pdf'],
        ]);
        $entity = $this->findShared(BusinessEntity::query(), $data['id'] ?? null) ?? new BusinessEntity();
        $resources = collect($data['resources'] ?? []);
        $entity->fill([
            'external_id' => $entity->exists ? $entity->external_id : $this->externalId($data['id'] ?? null),
            'name' => $data['name'], 'image_url' => $data['imageUrl'] ?? null, 'main_url' => $data['mainUrl'] ?? null,
            'links' => $resources->where('type', 'link')->values()->all(),
            'documents' => $resources->where('type', 'pdf')->values()->all(), 'is_active' => true,
        ])->save();
        $this->firestore->syncBusinessEntity($entity);
        return response()->json(['data' => $this->entityData($entity)], $entity->wasRecentlyCreated ? 201 : 200);
    }

    public function deleteEntity(Request $request, string $id): JsonResponse
    {
        $this->requireAdmin($request);
        $entity = $this->findShared(BusinessEntity::query(), $id);
        abort_unless($entity, 404);
        $this->firestore->deleteBusinessEntity($entity);
        $entity->delete();
        return response()->json([], 204);
    }

    private function categoryData(ContentCategory $row): array { return ['id' => (string) ($row->external_id ?: $row->id), 'nombre' => $row->name, 'scope' => $row->scope, 'descripcion' => (string) $row->description, 'imageUrl' => $row->imageUrl(), 'orden' => $row->sort_order, 'isActive' => $row->is_active, 'createdAt' => optional($row->created_at)?->toIso8601String()]; }
    private function alertData(Alert $row): array { return ['id' => (string) $row->id, 'source' => $row->source, 'title' => $row->title, 'description' => (string) $row->description, 'linkUrl' => (string) $row->link_url, 'sortOrder' => $row->sort_order, 'isActive' => $row->is_active, 'createdAt' => optional($row->created_at)?->toIso8601String(), 'updatedAt' => optional($row->updated_at)?->toIso8601String()]; }
    private function logData(AuditLog $row): array { return ['id' => (string) $row->id, 'usuarioId' => (string) ($row->user?->firebase_uid ?: $row->user_id ?: ''), 'accion' => $row->action, 'modulo' => $row->module, 'fecha' => optional($row->created_at)?->toIso8601String(), 'origen' => (string) data_get($row->metadata, 'origin', 'laravel'), 'detalle' => $row->description]; }
    private function contentData(Content $row): array { $payload = json_decode((string) $row->body, true) ?: []; $data = $payload['data'] ?? []; $type = $row->type === 'articulo' ? 'texto' : $row->type; $authorName = trim((string) ($data['author_name'] ?? '')); if ($authorName === '' && filled($row->author_id)) { $authorId = (string) $row->author_id; $authorName = (string) (User::query()->where('firebase_uid', $authorId)->orWhere(fn ($query) => ctype_digit($authorId) ? $query->whereKey((int) $authorId) : $query->whereRaw('1 = 0'))->value('name') ?? ''); } return ['id' => (string) ($row->external_id ?: $row->id), 'titulo' => $row->title, 'descripcion' => (string) $row->summary, 'tipo' => $type, 'url' => $type === 'video' ? ($data['video_url'] ?? '') : ($type === 'pdf' ? ($data['pdf_url'] ?? '') : ($type === 'evento' ? ($data['registration_url'] ?? '') : '')), 'contenido' => $type === 'video' ? ($data['transcript'] ?? '') : ($type === 'pdf' ? ($data['instructions'] ?? '') : ($type === 'evento' ? ($data['agenda'] ?? '') : ($data['body'] ?? ''))), 'imagen' => (string) ($payload['image_url'] ?? ''), 'categoria' => $row->contentCategory?->name ?? ($payload['category'] ?? ''), 'autorId' => (string) $row->author_id, 'autorNombre' => $authorName, 'fechaCreacion' => optional($row->created_at)?->toIso8601String(), 'estado' => $row->status === 'publicado' ? 'activo' : 'inactivo', 'destacado' => $row->featured, 'favoritos' => $row->favorites ?? [], 'vistos' => $row->views ?? [], 'metadata' => $data]; }
    private function microbusinessData(Microbusiness $row): array { return ['id' => (string) ($row->external_id ?: $row->id), 'nombre' => $row->name, 'descripcion' => (string) $row->description, 'categoria' => (string) $row->category, 'direccion' => (string) $row->address, 'latitud' => $row->latitude, 'longitud' => $row->longitude, 'mapsUrl' => (string) $row->maps_url, 'imagen' => $row->imageUrl(), 'propietarioId' => (string) $row->owner_id, 'contacto' => (string) $row->contact, 'horario' => (string) $row->schedule, 'estado' => $row->status, 'fechaCreacion' => optional($row->created_on_app_at ?? $row->created_at)?->toIso8601String(), 'favoritos' => $row->favorites ?? [], 'ratingPromedio' => $row->average_rating, 'totalCalificaciones' => $row->ratings_count, 'campos' => $row->custom_fields ?? []]; }
    private function entityData(BusinessEntity $row): array { return ['id' => (string) ($row->external_id ?: $row->id), 'name' => $row->name, 'imageUrl' => $row->imageUrl(), 'mainUrl' => (string) $row->main_url, 'createdAt' => optional($row->created_at)?->toIso8601String(), 'resources' => $row->firestoreResources()]; }

    private function findShared($query, ?string $id): ?Model { if (! filled($id)) return null; return ctype_digit($id) ? $query->whereKey((int) $id)->first() : $query->where('external_id', $id)->first(); }
    private function externalId(?string $id): ?string { return filled($id) && ! ctype_digit($id) ? $id : null; }
    private function uniqueSlug(string $model, string $name, Model $current): string { $base = Str::slug($name) ?: Str::random(8); $slug = $base; $i = 2; while ($model::query()->where('slug', $slug)->when($current->exists, fn ($q) => $q->whereKeyNot($current->getKey()))->exists()) $slug = $base.'-'.$i++; return $slug; }
    private function requireAdmin(Request $request): void { abort_unless(Roles::normalize($request->user()->role) === Roles::ADMIN_TI, 403); }
    private function requireSensitiveAccess(Request $request): void { abort_unless(Roles::canViewSensitive($request->user()->role), 403); }
    private function requireContentManager(Request $request): void { abort_unless(Roles::canManageContent($request->user()->role) || Roles::normalize($request->user()->role) === Roles::ADMIN_TI, 403); }
    private function authorizeBusiness(Request $request, Microbusiness $business, ?string $owner): void { $role = Roles::normalize($request->user()->role); $isAdmin = in_array($role, [Roles::ADMIN_TI, Roles::DOCENTE_ADMIN], true); abort_unless($isAdmin || ($owner && $owner === $request->user()->firebase_uid), 403); }
}
