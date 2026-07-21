<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ContentCategory;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Illuminate\Support\Facades\Storage;

class ContentCategoryController extends Controller
{
    public function index(): JsonResponse
    {
        $categories = ContentCategory::query()
            ->where('is_active', true)
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get()
            ->map(fn (ContentCategory $category) => [
                'id' => (string) $category->id,
                'nombre' => $category->name,
                'scope' => 'contenidos',
                'descripcion' => (string) ($category->description ?? ''),
                'imageUrl' => $category->imageUrl(),
                'orden' => $category->sort_order,
                'isActive' => $category->is_active,
                'createdAt' => optional($category->created_at)?->toIso8601String(),
            ]);

        return response()->json(['data' => $categories]);
    }

    public function image(ContentCategory $contentCategory): StreamedResponse
    {
        abort_unless(
            $contentCategory->image_path && Storage::disk('public')->exists($contentCategory->image_path),
            404,
        );

        return Storage::disk('public')->response($contentCategory->image_path);
    }
}
