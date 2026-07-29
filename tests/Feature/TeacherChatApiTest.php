<?php

namespace Tests\Feature;

use App\Constants\Roles;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TeacherChatApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_send_and_read_teacher_messages(): void
    {
        $user = User::factory()->create([
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
        ]);
        $teacher = User::factory()->create([
            'name' => 'Docente Real',
            'role' => Roles::DOCENTE,
            'is_active' => true,
            'teacher_description' => 'Especialista en mercadeo y ventas.',
        ]);
        Sanctum::actingAs($user);

        $this->postJson("/api/mobile/teacher-chats/{$teacher->id}/messages", [
            'text' => 'Necesito orientación',
        ])->assertCreated()
            ->assertJsonPath('data.text', 'Necesito orientación')
            ->assertJsonPath('data.senderName', $user->name);

        $this->getJson("/api/mobile/teacher-chats/{$teacher->id}/messages")
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.text', 'Necesito orientación');

        $this->assertDatabaseHas('teacher_conversations', [
            'user_id' => $user->id,
            'teacher_key' => (string) $teacher->id,
        ]);
        $this->assertDatabaseHas('teacher_chat_messages', ['text' => 'Necesito orientación']);
    }

    public function test_conversations_are_private_between_users(): void
    {
        $first = User::factory()->create(['role' => Roles::MICROEMPRESARIO, 'is_active' => true]);
        $second = User::factory()->create(['role' => Roles::MICROEMPRESARIO, 'is_active' => true]);
        $teacher = User::factory()->create(['role' => Roles::DOCENTE, 'is_active' => true]);

        Sanctum::actingAs($first);
        $this->postJson("/api/mobile/teacher-chats/{$teacher->id}/messages", [
            'text' => 'Mensaje privado',
        ])->assertCreated();

        Sanctum::actingAs($second);
        $this->getJson("/api/mobile/teacher-chats/{$teacher->id}/messages")
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_chat_requires_authentication(): void
    {
        $this->getJson('/api/mobile/teacher-chats/docente-inexistente/messages')
            ->assertUnauthorized();
    }

    public function test_chat_rejects_a_teacher_that_does_not_exist(): void
    {
        Sanctum::actingAs(User::factory()->create([
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
        ]));

        $this->postJson('/api/mobile/teacher-chats/docente-de-prueba/messages', [
            'text' => 'Este mensaje no debe guardarse',
        ])->assertNotFound();

        $this->assertDatabaseCount('teacher_conversations', 0);
        $this->assertDatabaseCount('teacher_chat_messages', 0);
    }

    public function test_teacher_directory_only_returns_real_active_teacher_users(): void
    {
        $viewer = User::factory()->create([
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
        ]);
        $teacher = User::factory()->create([
            'name' => 'Docente Real',
            'role' => Roles::DOCENTE,
            'is_active' => true,
            'teacher_description' => 'Especialista en mercadeo y ventas.',
        ]);
        User::factory()->create([
            'name' => 'Docente Inactivo',
            'role' => Roles::DOCENTE,
            'is_active' => false,
        ]);
        User::factory()->create([
            'name' => 'Usuario Regular',
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
        ]);
        Sanctum::actingAs($viewer);

        $this->getJson('/api/mobile/teachers')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.uid', (string) $teacher->id)
            ->assertJsonPath('data.0.name', 'Docente Real')
            ->assertJsonPath('data.0.description', 'Especialista en mercadeo y ventas.')
            ->assertJsonMissing(['name' => 'Docente Inactivo'])
            ->assertJsonMissing(['name' => 'Usuario Regular']);
    }
}
