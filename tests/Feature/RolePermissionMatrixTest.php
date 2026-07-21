<?php

namespace Tests\Feature;

use App\Constants\Roles;
use App\Models\Microbusiness;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RolePermissionMatrixTest extends TestCase
{
    use RefreshDatabase;

    /** @return array<string, User> */
    private function usersByRole(): array
    {
        return collect(Roles::ACTIVE_ROLES)->mapWithKeys(fn (string $role) => [
            $role => User::factory()->create([
                'role' => $role,
                'is_active' => true,
                'firebase_uid' => "uid-{$role}",
            ]),
        ])->all();
    }

    public function test_all_active_roles_can_open_shared_mobile_screens(): void
    {
        foreach ($this->usersByRole() as $role => $user) {
            Sanctum::actingAs($user);

            foreach (['categories', 'contents', 'microbusinesses', 'entities', 'teachers', 'forums'] as $resource) {
                $this->getJson("/api/mobile/{$resource}")->assertOk();
            }
        }
    }

    public function test_sensitive_dashboard_data_is_limited_to_academic_and_system_admins(): void
    {
        foreach ($this->usersByRole() as $role => $user) {
            Sanctum::actingAs($user);
            $allowed = in_array($role, [Roles::DOCENTE_ADMIN, Roles::ADMIN_TI], true);

            foreach (['users', 'logs'] as $resource) {
                $response = $this->getJson("/api/mobile/{$resource}");
                $allowed
                    ? $response->assertOk()
                    : $response->assertForbidden();
            }
        }
    }

    public function test_only_system_admin_can_manage_users_categories_and_entities(): void
    {
        $users = $this->usersByRole();
        $target = User::factory()->create([
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
            'firebase_uid' => 'target-user',
        ]);

        foreach ($users as $role => $user) {
            Sanctum::actingAs($user);
            $shouldPass = $role === Roles::ADMIN_TI;

            $userResponse = $this->postJson('/api/mobile/users/target-user', [
                'role' => Roles::MICROEMPRESARIO,
                'isActive' => true,
            ]);
            $categoryResponse = $this->postJson('/api/mobile/categories', [
                'id' => "category-{$role}",
                'nombre' => "Categoría {$role}",
                'scope' => 'contenidos',
            ]);
            $entityResponse = $this->postJson('/api/mobile/entities', [
                'id' => "entity-{$role}",
                'name' => "Entidad {$role}",
            ]);

            if ($shouldPass) {
                $userResponse->assertOk();
                $categoryResponse->assertCreated();
                $entityResponse->assertCreated();
            } else {
                $userResponse->assertForbidden();
                $categoryResponse->assertForbidden();
                $entityResponse->assertForbidden();
            }
        }

        $this->assertTrue($target->fresh()->is_active);
    }

    public function test_content_management_matches_the_role_contract(): void
    {
        foreach ($this->usersByRole() as $role => $user) {
            Sanctum::actingAs($user);
            $response = $this->postJson('/api/mobile/contents', [
                'id' => "content-{$role}",
                'titulo' => "Contenido {$role}",
                'tipo' => 'texto',
                'contenido' => 'Contenido de prueba de permisos.',
                'estado' => 'activo',
            ]);

            $role === Roles::MICROEMPRESARIO
                ? $response->assertForbidden()
                : $response->assertCreated();
        }
    }

    public function test_business_owners_and_admins_have_the_expected_write_access(): void
    {
        $users = $this->usersByRole();
        $business = Microbusiness::create([
            'external_id' => 'owned-business',
            'name' => 'Negocio existente',
            'owner_id' => 'uid-microempresario',
            'latitude' => 4.711,
            'longitude' => -74.0721,
            'status' => 'activo',
        ]);

        foreach ($users as $role => $user) {
            Sanctum::actingAs($user);
            $response = $this->postJson('/api/mobile/microbusinesses', [
                'id' => 'owned-business',
                'nombre' => 'Negocio actualizado',
                'propietarioId' => $business->owner_id,
                'latitud' => 4.711,
                'longitud' => -74.0721,
                'estado' => 'activo',
            ]);
            $allowed = in_array($role, [Roles::MICROEMPRESARIO, Roles::DOCENTE_ADMIN, Roles::ADMIN_TI], true);
            $allowed ? $response->assertOk() : $response->assertForbidden();
        }
    }

    public function test_inactive_accounts_are_rejected_even_with_an_existing_token(): void
    {
        $inactive = User::factory()->create([
            'role' => Roles::ADMIN_TI,
            'is_active' => false,
        ]);
        Sanctum::actingAs($inactive);

        $this->getJson('/api/auth/me')
            ->assertForbidden()
            ->assertJsonPath('message', 'Tu cuenta está desactivada. Contacte al administrador.');
    }

    public function test_public_api_registration_cannot_escalate_roles(): void
    {
        $this->postJson('/api/auth/register', [
            'name' => 'Registro público',
            'email' => 'registro-publico@example.com',
            'password' => 'ClaveSegura123*',
            'password_confirmation' => 'ClaveSegura123*',
            'role' => Roles::ADMIN_TI,
        ])->assertCreated()
            ->assertJsonPath('user.role', Roles::MICROEMPRESARIO);

        $this->assertDatabaseHas('users', [
            'email' => 'registro-publico@example.com',
            'role' => Roles::MICROEMPRESARIO,
        ]);
    }

    public function test_laravel_dashboard_is_only_available_to_system_admins(): void
    {
        foreach ($this->usersByRole() as $role => $user) {
            $response = $this->actingAs($user)->get('/dashboard');
            $role === Roles::ADMIN_TI
                ? $response->assertOk()
                : $response->assertForbidden();
        }
    }
}
