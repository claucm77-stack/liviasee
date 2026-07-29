<?php

namespace App\Services;

use App\Models\Content;
use App\Models\Alert;
use App\Models\ContentCategory;
use App\Models\BusinessEntity;
use App\Models\Microbusiness;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Firestore;
use Throwable;

class FirestoreSyncService
{
    private ?Firestore $firestore = null;

    public function __construct()
    {
        try {
            $this->firestore = (new Factory())
                ->withServiceAccount(config('services.firebase.credentials'))
                ->createFirestore();
        } catch (Throwable) {
            $this->firestore = null;
        }
    }

    public function syncContent(Content $content): void
    {
        $content->loadMissing('contentCategory');
        $payload = $this->decodeContentPayload($content);
        $data = $payload['data'] ?? [];
        $type = (string) ($content->type ?? 'articulo');

        $this->setDocument('contenidos', (string) $content->id, [
            'titulo' => $content->title,
            'descripcion' => (string) ($content->summary ?? ''),
            'tipo' => $this->normalizeContentType($type),
            'url' => $this->contentUrl($type, $data),
            'imagen' => (string) ($payload['image_url'] ?? ''),
            'categoria' => $this->contentCategory($content, $type, $payload),
            'autorId' => (string) ($content->author_id ?? ''),
            'autorNombre' => $this->contentAuthorName($content, $data),
            'fechaCreacion' => optional($content->created_at)?->toIso8601String() ?? now()->toIso8601String(),
            'estado' => $content->status === 'publicado' ? 'activo' : 'inactivo',
            'destacado' => false,
            // La app móvil muestra artículos y descripciones ampliadas desde este
            // campo. Mantenerlo también en metadata deja compatibilidad con
            // clientes que consumían el contrato anterior.
            'contenido' => $this->contentText($type, $data),
            'metadata' => $data,
        ]);
    }

    public function deleteContent(Content $content): void
    {
        $this->deleteDocument('contenidos', (string) $content->id);
    }

    private function contentAuthorName(Content $content, array $data): string
    {
        $name = trim((string) ($data['author_name'] ?? ''));
        if ($name !== '') return $name;

        $authorId = trim((string) ($content->author_id ?? ''));
        if ($authorId === '') return '';

        return (string) (\App\Models\User::query()
            ->where('firebase_uid', $authorId)
            ->orWhere(fn ($query) => ctype_digit($authorId) ? $query->whereKey((int) $authorId) : $query->whereRaw('1 = 0'))
            ->value('name') ?? '');
    }

    public function syncContentCategory(ContentCategory $category): void
    {
        $this->setDocument('categorias', 'content_'.$category->id, [
            'nombre' => $category->name,
            'scope' => 'contenidos',
            'descripcion' => (string) ($category->description ?? ''),
            'imageUrl' => $category->imageUrl(),
            'orden' => $category->sort_order,
            'isActive' => $category->is_active,
            'createdAt' => optional($category->created_at)?->toIso8601String() ?? now()->toIso8601String(),
        ]);
    }

    public function deleteContentCategory(ContentCategory $category): void
    {
        $this->deleteDocument('categorias', 'content_'.$category->id);
    }

    public function syncAlert(Alert $alert): void
    {
        $this->setDocument('alertas', (string) $alert->id, [
            'source' => $alert->source,
            'title' => $alert->title,
            'description' => (string) ($alert->description ?? ''),
            'linkUrl' => (string) ($alert->link_url ?? ''),
            'sortOrder' => $alert->sort_order,
            'isActive' => $alert->is_active,
            'createdAt' => optional($alert->created_at)?->toIso8601String() ?? now()->toIso8601String(),
            'updatedAt' => optional($alert->updated_at)?->toIso8601String() ?? now()->toIso8601String(),
        ]);
    }

    public function deleteAlert(Alert $alert): void
    {
        $this->deleteDocument('alertas', (string) $alert->id);
    }

    public function syncMicrobusiness(Microbusiness $business): void
    {
        $this->setDocument('micronegocios', (string) $business->id, [
            'nombre' => $business->name,
            'descripcion' => (string) ($business->description ?? ''),
            'categoria' => (string) ($business->category ?? ''),
            'direccion' => (string) ($business->address ?? ''),
            'latitud' => (float) $business->latitude,
            'longitud' => (float) $business->longitude,
            'mapsUrl' => (string) ($business->maps_url ?? ''),
            'imagen' => (string) ($business->image_url ?? ''),
            'propietarioId' => (string) ($business->owner_id ?? ''),
            'contacto' => (string) ($business->contact ?? ''),
            'horario' => (string) ($business->schedule ?? ''),
            'estado' => $business->status,
            'fechaCreacion' => optional($business->created_on_app_at ?? $business->created_at)?->toIso8601String() ?? now()->toIso8601String(),
            'favoritos' => $business->favorites ?? [],
            'ratingPromedio' => $business->average_rating,
            'totalCalificaciones' => $business->ratings_count,
        ]);
    }

    public function deleteMicrobusiness(Microbusiness $business): void
    {
        $this->deleteDocument('micronegocios', (string) $business->id);
    }

    public function syncBusinessEntity(BusinessEntity $entity): void
    {
        $this->setDocument('entidades', (string) $entity->id, [
            'name' => $entity->name,
            'imageUrl' => $entity->imageUrl(),
            'mainUrl' => (string) ($entity->main_url ?? ''),
            'createdAt' => optional($entity->created_at)?->toIso8601String() ?? now()->toIso8601String(),
            'resources' => $entity->firestoreResources(),
        ]);
    }

    public function deleteBusinessEntity(BusinessEntity $entity): void
    {
        $this->deleteDocument('entidades', (string) $entity->id);
    }

    private function setDocument(string $collection, string $id, array $data): void
    {
        if ($this->firestore === null) {
            return;
        }

        try {
            $this->firestore->database()
                ->collection($collection)
                ->document($id)
                ->set($data, ['merge' => true]);
        } catch (Throwable) {
            // El panel local no debe fallar si Firebase no esta disponible.
        }
    }

    private function deleteDocument(string $collection, string $id): void
    {
        if ($this->firestore === null) {
            return;
        }

        try {
            $this->firestore->database()
                ->collection($collection)
                ->document($id)
                ->delete();
        } catch (Throwable) {
            // El panel local no debe fallar si Firebase no esta disponible.
        }
    }

    private function normalizeContentType(string $type): string
    {
        return match ($type) {
            'video' => 'video',
            'pdf' => 'pdf',
            'evento' => 'evento',
            default => 'texto',
        };
    }

    private function contentCategory(Content $content, string $type, array $payload = []): string
    {
        $linkedCategory = trim((string) ($content->contentCategory?->name ?? ''));
        if ($linkedCategory !== '') return $linkedCategory;

        $category = trim((string) ($payload['category'] ?? ''));
        if ($category !== '') {
            return $category;
        }

        return match ($type) {
            'video' => 'Repositorio en video',
            'pdf' => 'Artículos Relacionados',
            'evento' => 'Cronograma Actividades',
            default => 'Artículos Populares',
        };
    }

    private function contentUrl(string $type, array $data): string
    {
        return match ($type) {
            'video' => (string) ($data['video_url'] ?? ''),
            'pdf' => (string) ($data['pdf_url'] ?? ''),
            'evento' => (string) ($data['registration_url'] ?? ''),
            default => '',
        };
    }

    private function contentText(string $type, array $data): string
    {
        return match ($type) {
            'video' => (string) ($data['transcript'] ?? ''),
            'pdf' => (string) ($data['instructions'] ?? ''),
            'evento' => (string) ($data['agenda'] ?? ''),
            default => (string) ($data['body'] ?? ''),
        };
    }

    private function decodeContentPayload(Content $content): array
    {
        $decoded = json_decode((string) $content->body, true);
        if (is_array($decoded)) {
            return $decoded;
        }

        return [
            'type' => $content->type,
            'category' => $content->contentCategory?->name ?? '',
            'image_url' => '',
            'data' => [
                'body' => (string) ($content->body ?? ''),
            ],
        ];
    }
}
