<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('content_categories', function (Blueprint $table) {
            $table->string('external_id')->nullable()->unique()->after('id');
            $table->string('scope')->default('contenidos')->after('slug');
            $table->text('image_url')->nullable()->after('image_path');
        });

        Schema::table('contents', function (Blueprint $table) {
            $table->string('external_id')->nullable()->unique()->after('id');
            $table->string('author_id')->nullable()->after('content_category_id');
            $table->boolean('featured')->default(false)->after('status');
            $table->json('favorites')->nullable()->after('featured');
            $table->json('views')->nullable()->after('favorites');
        });

        Schema::table('microbusinesses', function (Blueprint $table) {
            $table->string('external_id')->nullable()->unique()->after('id');
            $table->json('custom_fields')->nullable()->after('ratings_count');
        });

        Schema::table('business_entities', function (Blueprint $table) {
            $table->string('external_id')->nullable()->unique()->after('id');
            $table->text('image_url')->nullable()->after('image_path');
        });
    }

    public function down(): void
    {
        Schema::table('business_entities', fn (Blueprint $table) => $table->dropColumn(['external_id', 'image_url']));
        Schema::table('microbusinesses', fn (Blueprint $table) => $table->dropColumn(['external_id', 'custom_fields']));
        Schema::table('contents', fn (Blueprint $table) => $table->dropColumn(['external_id', 'author_id', 'featured', 'favorites', 'views']));
        Schema::table('content_categories', fn (Blueprint $table) => $table->dropColumn(['external_id', 'scope', 'image_url']));
    }
};
