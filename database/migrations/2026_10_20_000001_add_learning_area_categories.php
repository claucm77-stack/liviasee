<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('content_categories')) {
            return;
        }

        $now = now();
        foreach ([
            ['Publicidad y Mercadeo', 10],
            ['Administración de Empresas', 20],
            ['Contabilidad', 30],
        ] as [$name, $order]) {
            DB::table('content_categories')->updateOrInsert(
                ['name' => $name],
                [
                    'slug' => Str::slug($name),
                    'scope' => 'contenidos',
                    'sort_order' => $order,
                    'is_active' => true,
                    'updated_at' => $now,
                    'created_at' => $now,
                ],
            );
        }
    }

    public function down(): void
    {
        // These are real admin-managed categories; keep them if the migration is rolled back.
    }
};
