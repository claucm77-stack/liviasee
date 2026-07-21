<?php

namespace Tests\Feature;

use App\Constants\Roles;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ForumApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_associate_a_forum_with_a_real_teacher(): void
    {
        $admin = User::factory()->create(['role' => Roles::ADMIN_TI, 'is_active' => true]);
        $teacher = User::factory()->create([
            'name' => 'Docente Asociado',
            'role' => Roles::DOCENTE,
            'is_active' => true,
        ]);
        Sanctum::actingAs($admin);

        $response = $this->postJson('/api/mobile/forums', [
            'title' => 'Foro real',
            'category' => 'Contabilidad',
            'teacher_id' => (string) $teacher->id,
        ])->assertCreated()
            ->assertJsonPath('data.teacherId', (string) $teacher->id)
            ->assertJsonPath('data.teacherName', 'Docente Asociado')
            ->assertJsonPath('data.status', 'Pendiente de respuesta');

        $topicId = $response->json('data.id');
        $this->assertDatabaseHas('forum_topics', [
            'id' => $topicId,
            'teacher_id' => $teacher->id,
            'author_id' => $admin->id,
        ]);
        $this->getJson('/api/mobile/forums')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.title', 'Foro real');
    }

    public function test_assigned_teacher_can_reply_and_another_teacher_cannot(): void
    {
        $author = User::factory()->create(['role' => Roles::MICROEMPRESARIO, 'is_active' => true]);
        $assigned = User::factory()->create(['role' => Roles::DOCENTE, 'is_active' => true]);
        $other = User::factory()->create(['role' => Roles::DOCENTE, 'is_active' => true]);
        Sanctum::actingAs($author);
        $topicId = $this->postJson('/api/mobile/forums', [
            'title' => 'Consulta asignada',
            'teacher_id' => (string) $assigned->id,
        ])->assertCreated()->json('data.id');

        Sanctum::actingAs($other);
        $this->postJson("/api/mobile/forums/{$topicId}/replies", ['text' => 'No autorizada'])
            ->assertForbidden();

        Sanctum::actingAs($assigned);
        $this->postJson("/api/mobile/forums/{$topicId}/replies", ['text' => 'Respuesta real'])
            ->assertCreated()
            ->assertJsonPath('data.teacherName', $assigned->name);
        $this->getJson('/api/mobile/forums')
            ->assertJsonPath('data.0.status', 'Respondido por docente')
            ->assertJsonPath('data.0.replies.0.text', 'Respuesta real');
    }

    public function test_forum_rejects_inactive_or_nonexistent_teacher(): void
    {
        $admin = User::factory()->create(['role' => Roles::ADMIN_TI, 'is_active' => true]);
        $inactive = User::factory()->create(['role' => Roles::DOCENTE, 'is_active' => false]);
        Sanctum::actingAs($admin);

        $this->postJson('/api/mobile/forums', [
            'title' => 'No debe existir',
            'teacher_id' => (string) $inactive->id,
        ])->assertNotFound();
        $this->postJson('/api/mobile/forums', [
            'title' => 'Tampoco debe existir',
            'teacher_id' => 'docente-ficticio',
        ])->assertNotFound();
        $this->assertDatabaseCount('forum_topics', 0);
    }

    public function test_forums_require_authentication(): void
    {
        $this->getJson('/api/mobile/forums')->assertUnauthorized();
        $this->postJson('/api/mobile/forums', [])->assertUnauthorized();
    }
}
