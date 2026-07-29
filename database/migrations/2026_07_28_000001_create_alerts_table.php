<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('alerts', function (Blueprint $table) {
            $table->id();
            $table->string('source', 160);
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('link_url', 2000)->nullable();
            $table->unsignedInteger('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        $now = now();
        DB::table('alerts')->insert([
            ['source' => 'DIAN', 'title' => 'Calendario tributario para microempresas', 'description' => 'Fuente oficial pendiente de sincronización', 'sort_order' => 10, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now],
            ['source' => 'Cámara de Comercio', 'title' => 'Renovación de matrícula mercantil', 'description' => 'Segmentado por sector económico', 'sort_order' => 20, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now],
            ['source' => 'SIC', 'title' => 'Recomendaciones de protección al consumidor', 'description' => 'Actualización normativa', 'sort_order' => 30, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now],
            ['source' => 'Secretaría de Desarrollo Económico', 'title' => 'Convocatorias y programas de fomento', 'description' => 'Alertas personalizables', 'sort_order' => 40, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now],
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('alerts');
    }
};
