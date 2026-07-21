<?php

namespace Tests\Feature;

use App\Constants\Roles;
use App\Models\Content;
use App\Models\ContentCategory;
use App\Models\PlatformSetting;
use App\Models\User;
use App\Services\FirebaseUserService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery;
use Tests\TestCase;

class AdminPanelTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $firebaseMock = Mockery::mock(FirebaseUserService::class);
        $firebaseMock->shouldReceive('paginateUsers')->andReturn(new \Illuminate\Pagination\LengthAwarePaginator([], 0, 10, 1));
        $firebaseMock->shouldReceive('createUser')->andReturnUsing(function (array $payload) {
            return 'uid_'.md5((string) ($payload['email'] ?? uniqid('', true)));
        });
        $firebaseMock->shouldReceive('getUserByUid')->andReturnUsing(function (string $uid) {
            if ($uid === 'missing-user') {
                return null;
            }

            $local = User::where('firebase_uid', $uid)->first();

            if (!$local) {
                return null;
            }

            return [
                'uid' => $local->firebase_uid,
                'name' => $local->name,
                'email' => $local->email,
                'role' => $local->role,
                'is_active' => $local->is_active,
            ];
        });
        $firebaseMock->shouldReceive('updateUser')->andReturnTrue();
        $firebaseMock->shouldReceive('deleteUser')->andReturnTrue();

        $this->app->instance(FirebaseUserService::class, $firebaseMock);
    }

    public function test_admin_can_access_users_index(): void
    {
        $admin = User::factory()->create([
            'role' => Roles::ADMIN_TI,
            'is_active' => true,
        ]);

        $response = $this->actingAs($admin)->get(route('admin.users.index'));

        $response->assertOk();
    }

    public function test_admin_can_edit_content_assigned_to_an_inactive_category(): void
    {
        $admin = User::factory()->create([
            'role' => Roles::ADMIN_TI,
            'is_active' => true,
        ]);
        $category = ContentCategory::query()->create([
            'name' => 'Categoría inactiva',
            'slug' => 'categoria-inactiva',
            'is_active' => false,
        ]);
        $content = Content::query()->create([
            'title' => 'Contenido de prueba',
            'slug' => 'contenido-de-prueba',
            'content_category_id' => $category->id,
        ]);

        $response = $this->actingAs($admin)->get(route('admin.contents.edit', $content));

        $response->assertOk();
        $response->assertSee('Categoría inactiva');
    }

    public function test_non_admin_cannot_access_admin_routes(): void
    {
        $user = User::factory()->create([
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
        ]);

        $response = $this->actingAs($user)->get(route('admin.users.index'));

        $response->assertForbidden();
    }

    public function test_inactive_admin_cannot_access_admin_routes(): void
    {
        $admin = User::factory()->create([
            'role' => Roles::ADMIN_TI,
            'is_active' => false,
        ]);

        $response = $this->actingAs($admin)->get(route('admin.users.index'));

        $response->assertForbidden();
    }

    public function test_admin_can_create_user(): void
    {
        $admin = User::factory()->create([
            'role' => Roles::ADMIN_TI,
            'is_active' => true,
        ]);

        $payload = [
            'name' => 'Docente Demo',
            'email' => 'docente@example.com',
            'password' => 'Password123*',
            'password_confirmation' => 'Password123*',
            'role' => Roles::DOCENTE,
            'is_active' => 1,
        ];

        $response = $this->actingAs($admin)->post(route('admin.users.store'), $payload);

        $response->assertRedirect(route('admin.users.index'));
        $this->assertDatabaseHas('users', [
            'email' => 'docente@example.com',
            'role' => Roles::DOCENTE,
            'is_active' => 1,
        ]);
    }

    public function test_admin_can_update_user(): void
    {
        $admin = User::factory()->create([
            'role' => Roles::ADMIN_TI,
            'is_active' => true,
        ]);

        $target = User::factory()->create([
            'firebase_uid' => 'uid_target_update',
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
        ]);

        $response = $this->actingAs($admin)->put(route('admin.users.update', ['user' => $target->firebase_uid]), [
            'name' => 'Usuario Editado',
            'email' => $target->email,
            'role' => Roles::DOCENTE,
            'is_active' => 0,
        ]);

        $response->assertRedirect(route('admin.users.index'));
        $this->assertDatabaseHas('users', [
            'id' => $target->id,
            'name' => 'Usuario Editado',
            'role' => Roles::DOCENTE,
            'is_active' => 0,
        ]);
    }

    public function test_admin_can_create_user_without_is_active_field_defaults_to_inactive(): void
    {
        $admin = User::factory()->create([
            'role' => Roles::ADMIN_TI,
            'is_active' => true,
        ]);

        $payload = [
            'name' => 'Usuario Sin Check',
            'email' => 'sincheck@example.com',
            'password' => 'Password123*',
            'password_confirmation' => 'Password123*',
            'role' => Roles::MICROEMPRESARIO,
        ];

        $response = $this->actingAs($admin)->post(route('admin.users.store'), $payload);

        $response->assertRedirect(route('admin.users.index'));
        $this->assertDatabaseHas('users', [
            'email' => 'sincheck@example.com',
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => 0,
        ]);
    }

    public function test_admin_can_update_user_role_without_is_active_field(): void
    {
        $admin = User::factory()->create([
            'role' => Roles::ADMIN_TI,
            'is_active' => true,
        ]);

        $target = User::factory()->create([
            'firebase_uid' => 'uid_target_update_without_active',
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
        ]);

        $response = $this->actingAs($admin)->put(route('admin.users.update', ['user' => $target->firebase_uid]), [
            'name' => 'Usuario Rol Editado',
            'email' => $target->email,
            'role' => Roles::DOCENTE,
        ]);

        $response->assertRedirect(route('admin.users.index'));
        $this->assertDatabaseHas('users', [
            'id' => $target->id,
            'name' => 'Usuario Rol Editado',
            'role' => Roles::DOCENTE,
            'is_active' => 0,
        ]);
    }

    public function test_admin_cannot_delete_himself(): void
    {
        $admin = User::factory()->create([
            'role' => Roles::ADMIN_TI,
            'is_active' => true,
        ]);

        $admin->update(['firebase_uid' => 'uid_admin_self']);

        $response = $this->actingAs($admin)->delete(route('admin.users.destroy', ['user' => $admin->firebase_uid]));

        $response->assertRedirect(route('admin.users.index'));
        $this->assertDatabaseHas('users', [
            'id' => $admin->id,
        ]);
    }

    public function test_admin_can_delete_other_user(): void
    {
        $admin = User::factory()->create([
            'role' => Roles::ADMIN_TI,
            'is_active' => true,
        ]);

        $target = User::factory()->create([
            'firebase_uid' => 'uid_target_delete',
        ]);

        $response = $this->actingAs($admin)->delete(route('admin.users.destroy', ['user' => $target->firebase_uid]));

        $response->assertRedirect(route('admin.users.index'));
        $this->assertDatabaseMissing('users', [
            'id' => $target->id,
        ]);
    }

    public function test_admin_can_update_platform_settings(): void
    {
        $admin = User::factory()->create([
            'role' => Roles::ADMIN_TI,
            'is_active' => true,
        ]);

        PlatformSetting::query()->create([
            'platform_name' => 'Base',
            'contact_email' => null,
            'support_whatsapp' => null,
            'about' => null,
            'maintenance_mode' => false,
        ]);

        $response = $this->actingAs($admin)->patch(route('admin.settings.update'), [
            'platform_name' => 'Nueva Plataforma',
            'contact_email' => 'nuevo@plataforma.com',
            'support_whatsapp' => '+593999999999',
            'about' => 'Descripción actualizada',
            'maintenance_mode' => 1,
        ]);

        $response->assertRedirect(route('admin.settings.edit'));
        $this->assertDatabaseHas('platform_settings', [
            'platform_name' => 'Nueva Plataforma',
            'contact_email' => 'nuevo@plataforma.com',
            'maintenance_mode' => 1,
        ]);
    }
}
