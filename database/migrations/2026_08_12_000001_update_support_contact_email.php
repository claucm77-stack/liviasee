<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('platform_settings')
            ->where('contact_email', 'soporte.aulas@sanmartin.edu.co')
            ->update(['contact_email' => 'juan.drodriguez@sanmartin.edu.co']);
    }

    public function down(): void
    {
        DB::table('platform_settings')
            ->where('contact_email', 'juan.drodriguez@sanmartin.edu.co')
            ->update(['contact_email' => 'soporte.aulas@sanmartin.edu.co']);
    }
};
