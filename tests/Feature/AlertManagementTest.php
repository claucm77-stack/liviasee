<?php

namespace Tests\Feature;

use App\Constants\Roles;
use App\Models\Alert;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AlertManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_default_alerts_are_seeded_and_visible_in_the_app(): void
    {
        $user = User::factory()->create([
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
        ]);
        Sanctum::actingAs($user);

        $this->assertDatabaseCount('alerts', 4);
        $this->getJson('/api/mobile/alerts')
            ->assertOk()
            ->assertJsonFragment([
                'source' => 'DIAN',
                'title' => 'Calendario tributario para microempresas',
            ]);
    }

    public function test_web_admin_can_create_update_and_delete_an_alert(): void
    {
        $admin = User::factory()->create([
            'role' => Roles::ADMIN_TI,
            'is_active' => true,
        ]);

        $this->actingAs($admin)->post(route('admin.alerts.store'), [
            'source' => 'Ministerio de Comercio',
            'title' => 'Convocatoria nacional',
            'description' => 'Inscripciones abiertas.',
            'link_url' => 'https://example.com/convocatoria',
            'sort_order' => 5,
            'is_active' => 1,
        ])->assertRedirect(route('admin.alerts.index'));

        $alert = Alert::query()->where('title', 'Convocatoria nacional')->firstOrFail();
        $this->actingAs($admin)->put(route('admin.alerts.update', $alert), [
            'source' => 'MinComercio',
            'title' => 'Convocatoria actualizada',
            'description' => 'Nueva fecha.',
            'sort_order' => 6,
        ])->assertRedirect(route('admin.alerts.index'));

        $this->assertDatabaseHas('alerts', [
            'id' => $alert->id,
            'title' => 'Convocatoria actualizada',
            'is_active' => false,
        ]);

        $this->actingAs($admin)
            ->delete(route('admin.alerts.destroy', $alert))
            ->assertRedirect(route('admin.alerts.index'));
        $this->assertDatabaseMissing('alerts', ['id' => $alert->id]);
    }

    public function test_app_admin_can_manage_alerts_and_regular_users_only_see_active_ones(): void
    {
        $admin = User::factory()->create([
            'role' => Roles::ADMIN_TI,
            'is_active' => true,
        ]);
        Sanctum::actingAs($admin);

        $created = $this->postJson('/api/mobile/alerts', [
            'source' => 'Alcaldía',
            'title' => 'Alerta editable',
            'description' => 'Texto inicial',
            'sortOrder' => 1,
            'isActive' => false,
        ])->assertCreated()
            ->assertJsonPath('data.isActive', false)
            ->json('data');

        $this->postJson('/api/mobile/alerts', [
            'id' => (int) $created['id'],
            'source' => 'Alcaldía',
            'title' => 'Alerta editada desde app',
            'description' => 'Texto actualizado',
            'sortOrder' => 2,
            'isActive' => false,
        ])->assertOk();

        $regular = User::factory()->create([
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
        ]);
        Sanctum::actingAs($regular);
        $this->getJson('/api/mobile/alerts')
            ->assertOk()
            ->assertJsonMissing(['title' => 'Alerta editada desde app']);

        $this->postJson('/api/mobile/alerts', [
            'source' => 'No autorizado',
            'title' => 'No debe guardarse',
        ])->assertForbidden();
    }
}
