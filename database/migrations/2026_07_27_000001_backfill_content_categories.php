<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('contents') || ! Schema::hasTable('content_categories')) {
            return;
        }

        DB::transaction(function (): void {
            $now = now();
            $defaults = [
                ['name' => 'Conferencia en vivo', 'sort_order' => 100],
                ['name' => 'Repositorio en video', 'sort_order' => 110],
                ['name' => 'Artículos Populares', 'sort_order' => 120],
                ['name' => 'Artículos Relacionados', 'sort_order' => 130],
                ['name' => 'Cronograma Actividades', 'sort_order' => 140],
            ];

            foreach ($defaults as $category) {
                DB::table('content_categories')->insertOrIgnore([
                    'name' => $category['name'],
                    'slug' => Str::slug($category['name']),
                    'scope' => 'contenidos',
                    'sort_order' => $category['sort_order'],
                    'is_active' => true,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
                DB::table('content_categories')
                    ->where('name', $category['name'])
                    ->update([
                        'scope' => 'contenidos',
                        'sort_order' => $category['sort_order'],
                        'is_active' => true,
                        'updated_at' => $now,
                    ]);
            }

            $categoryIds = DB::table('content_categories')->pluck('id', 'name');

            DB::table('contents')
                ->whereNull('content_category_id')
                ->orderBy('id')
                ->chunkById(200, function ($contents) use ($categoryIds): void {
                    foreach ($contents as $content) {
                        $payload = json_decode((string) ($content->body ?? ''), true);
                        $payload = is_array($payload) ? $payload : [];
                        $categoryName = trim((string) ($payload['category'] ?? ''));
                        $categoryId = $categoryName !== ''
                            ? $categoryIds->get($categoryName)
                            : null;

                        if (! $categoryId) {
                            $fallback = match ((string) ($content->type ?? '')) {
                                'video' => 'Repositorio en video',
                                'pdf' => 'Artículos Relacionados',
                                'evento' => 'Cronograma Actividades',
                                default => 'Artículos Populares',
                            };
                            $categoryId = $categoryIds->get($fallback);
                        }

                        if ($categoryId) {
                            DB::table('contents')
                                ->where('id', $content->id)
                                ->update(['content_category_id' => $categoryId]);
                        }
                    }
                });
        });
    }

    public function down(): void
    {
        // No se revierte para evitar desasignar o eliminar categorías en uso.
    }
};
