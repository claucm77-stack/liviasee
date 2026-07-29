<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Content;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ContentController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $perPage = max(1, min((int) $request->integer('per_page', 20), 100));

        $query = Content::query()
            ->with('contentCategory')
            ->where('status', 'publicado')
            ->orderByDesc('published_at')
            ->orderByDesc('created_at');

        $contents = $query->paginate($perPage);

        $data = $contents->getCollection()
            ->filter->hasUsableDestination()
            ->map(function (Content $content) {
            $payload = $this->decodePayload($content);
            $metadata = $payload['data'] ?? [];
            $type = (string) ($content->type ?? 'articulo');

            return [
                'id' => (string) $content->id,
                'titulo' => (string) $content->title,

                    'descripcion' => (string) ($content->summary ?? ''),
                    'tipo' => $this->contentType($type),
                    'url' => $this->contentUrl($type, $metadata),
                    'imagen' => (string) ($payload['image_url'] ?? ''),
                    'categoria' => $this->contentCategory($content, $type, $payload),
                    'autorId' => (string) ($content->author_id ?? ''),
                    'autorNombre' => $this->contentAuthorName($content, $metadata),
                    'fechaCreacion' => optional($content->created_at)?->toIso8601String(),
                    'estado' => $content->status === 'publicado' ? 'activo' : 'inactivo',
                    'destacado' => false,
                    'favoritos' => [],
                    'vistos' => [],
                    // Para que la app muestre el contenido completo,
                    // incluimos el body según el tipo.
                    'contenido' => $this->extractContentText($type, $metadata),
                    'metadata' => $metadata,
                ];

            });


        return response()->json([
            'data' => $data,
            'meta' => [
                'current_page' => $contents->currentPage(),
                'last_page' => $contents->lastPage(),
                'per_page' => $contents->perPage(),
                'total' => $contents->total(),
            ],
        ]);
    }

    private function contentType(string $type): string
    {
        return match ($type) {
            'video' => 'video',
            'pdf' => 'pdf',
            'evento' => 'evento',
            default => 'texto',
        };
    }

    private function contentAuthorName(Content $content, array $metadata): string
    {
        $name = trim((string) ($metadata['author_name'] ?? ''));
        if ($name !== '') {
            return $name;
        }

        $authorId = trim((string) ($content->author_id ?? ''));
        if ($authorId === '') {
            return '';
        }

        return (string) (\App\Models\User::query()
            ->where('firebase_uid', $authorId)
            ->orWhere(fn ($query) => ctype_digit($authorId) ? $query->whereKey((int) $authorId) : $query->whereRaw('1 = 0'))
            ->value('name') ?? '');
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

    private function contentUrl(string $type, array $metadata): string
    {
        return match ($type) {
            'video' => (string) ($metadata['video_url'] ?? ''),
            'pdf' => (string) ($metadata['pdf_url'] ?? ''),
            'evento' => (string) ($metadata['registration_url'] ?? ''),
            default => '',
        };
    }

    private function extractContentText(string $type, array $metadata): string
    {
        // Coincide con buildBodyPayload() del Admin.
        return match ($type) {
            'video' => (string) ($metadata['transcript'] ?? ''),
            'pdf' => (string) ($metadata['instructions'] ?? ''),
            'evento' => (string) ($metadata['agenda'] ?? ''),
            default => (string) ($metadata['body'] ?? ''),
        };
    }

    private function decodePayload(Content $content): array
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
