<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('users') || ! Schema::hasTable('microbusinesses')) {
            return;
        }

        DB::table('users')
            ->whereNotNull('firebase_uid')
            ->where('firebase_uid', '<>', '')
            ->orderBy('id')
            ->select(['id', 'firebase_uid'])
            ->each(function (object $user): void {
                DB::table('microbusinesses')
                    ->where('owner_id', (string) $user->id)
                    ->update(['owner_id' => $user->firebase_uid]);
            });
    }

    public function down(): void
    {
        // Owner IDs are normalized to the canonical Firebase identifier permanently.
    }
};
