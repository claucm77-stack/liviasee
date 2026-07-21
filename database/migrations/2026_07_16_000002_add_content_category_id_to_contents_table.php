<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('contents', function (Blueprint $table) {
            $table->foreignId('content_category_id')
                ->nullable()
                ->after('type')
                ->constrained('content_categories')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('contents', function (Blueprint $table) {
            $table->dropConstrainedForeignId('content_category_id');
        });
    }
};
