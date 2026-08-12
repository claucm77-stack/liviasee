<?php

namespace Database\Seeders;

use App\Constants\Roles;
use App\Models\PlatformSetting;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        User::query()->updateOrCreate(
            ['email' => 'admin@plataforma.com'],
            [
                'name' => 'Administrador TI',
                'password' => 'Admin12345*',
                'role' => Roles::ADMIN_TI,
                'is_active' => true,
                'email_verified_at' => now(),
            ]
        );

        User::factory()->count(5)->create([
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
        ]);

        PlatformSetting::query()->updateOrCreate(
            ['id' => 1],
            [
                'platform_name' => 'Livi@se',
                'contact_email' => 'juan.drodriguez@sanmartin.edu.co',
                'support_whatsapp' => '+570000000000',
                'about' => 'Plataforma de acompañamiento académico, agenda, directorio y alertas para microempresarios.',
                'maintenance_mode' => false,
            ]
        );
    }
}
